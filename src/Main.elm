module Main exposing (..)

import Array
import Browser
import Bytes
import Bytes.Decode
import Html as H
import Html.Attributes as Ha
import Html.Events as He
import Html.Keyed as Hk
import Html.Lazy as Hl
import Http
import Http.Detailed
import Json.Decode as Jd
import Json.Encode as Je
import List
import Maybe



-- MAIN


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = \_ -> Sub.none
        , view = view
        }



-- MODEL


origin : String
origin =
    "http://localhost:5000"


type alias Index =
    Int


type alias Id =
    Int


type alias Todo =
    { id : Id
    , isEditing : Bool
    , editText : String
    , text : String
    }


type alias Model =
    { nextText : String
    , lastError : Maybe String
    , todos : Array.Array Todo
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { nextText = ""
      , lastError = Nothing
      , todos = Array.empty
      }
    , Http.get
        { url = origin ++ "/api/items"
        , expect = Http.Detailed.expectJson GotTodos todosDecoder
        }
    )



-- UPDATE


type Msg
    = ChangedNextText String
    | ChangedTodo Index String
    | PushedAddButton String
    | PushedCancelEdit Index
    | PushedDeleteTodo Id
    | PushedEdit Index
    | PushedSaveEdit Id String
    | GotAddedNextText (Result (Http.Detailed.Error String) ( Http.Metadata, Todo ))
    | GotDeletedTodo Id (Result (Http.Detailed.Error Bytes.Bytes) ())
    | GotSavedEdit (Result (Http.Detailed.Error String) ( Http.Metadata, Todo ))
    | GotTodos (Result (Http.Detailed.Error String) ( Http.Metadata, List Todo ))


{-| for item in array: if test(item): return Just index of item else Nothing
-}
findIndex : (a -> Bool) -> Array.Array a -> Maybe Index
findIndex predicate array =
    findIndexHelper 0 predicate array


findIndexHelper : Index -> (a -> Bool) -> Array.Array a -> Maybe Index
findIndexHelper index predicate array =
    Array.get index array
        |> Maybe.andThen
            (\item ->
                if predicate item then
                    Just index

                else
                    findIndexHelper (index + 1) predicate array
            )


sizedString : Bytes.Decode.Decoder String
sizedString =
    Bytes.Decode.unsignedInt32 Bytes.BE
        |> Bytes.Decode.andThen Bytes.Decode.string


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ChangedNextText t ->
            ( { model | nextText = t }, Cmd.none )

        ChangedTodo index newEditText ->
            case Array.get index model.todos of
                Just todo ->
                    ( { model | todos = Array.set index { todo | editText = newEditText } model.todos }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        GotAddedNextText result ->
            case result of
                Ok ( _, todo ) ->
                    ( { model | todos = Array.push todo model.todos }, Cmd.none )

                Err err ->
                    ( { model | lastError = Just <| httpDetailedErrorStrToStr err }, Cmd.none )

        GotDeletedTodo id result ->
            case result of
                Ok _ ->
                    ( { model | todos = Array.filter (\t -> t.id /= id) model.todos }
                    , Cmd.none
                    )

                Err err ->
                    ( { model | lastError = Just <| httpDetailedErrorBytesToStr err }, Cmd.none )

        GotTodos result ->
            case result of
                Ok ( _, todos ) ->
                    ( { model | todos = Array.fromList todos }, Cmd.none )

                Err err ->
                    ( { model | lastError = Just <| httpDetailedErrorStrToStr err }, Cmd.none )

        GotSavedEdit result ->
            case result of
                Ok ( _, todo ) ->
                    case findIndex (\i -> i.id == todo.id) model.todos of
                        Just index ->
                            ( { model | todos = Array.set index todo model.todos }, Cmd.none )

                        Nothing ->
                            ( model, Cmd.none )

                Err err ->
                    ( { model | lastError = Just <| httpDetailedErrorStrToStr err }, Cmd.none )

        PushedAddButton t ->
            ( { model | nextText = "" }
            , Http.request
                { method = "POST"
                , headers = []
                , url = origin ++ "/api/items"
                , body = Http.jsonBody (Je.object [ ( "text", Je.string t ) ])
                , expect = Http.Detailed.expectJson GotAddedNextText todoDecoder
                , timeout = Nothing
                , tracker = Nothing
                }
            )

        PushedCancelEdit index ->
            case Array.get index model.todos of
                Just todo ->
                    ( { model | todos = Array.set index { todo | isEditing = False } model.todos }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        PushedDeleteTodo id ->
            ( model
            , Http.request
                { method = "DELETE"
                , headers = []
                , url = origin ++ "/api/items/" ++ String.fromInt id
                , body = Http.emptyBody
                , expect = Http.Detailed.expectWhatever (GotDeletedTodo id)
                , timeout = Nothing
                , tracker = Nothing
                }
            )

        PushedEdit index ->
            case Array.get index model.todos of
                Just todo ->
                    ( { model
                        | todos =
                            Array.set
                                index
                                { todo | isEditing = True, editText = todo.text }
                                model.todos
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        PushedSaveEdit id newText ->
            ( model
            , Http.request
                { method = "PATCH"
                , headers = []
                , url = origin ++ "/api/items/" ++ String.fromInt id
                , body = Http.jsonBody (Je.object [ ( "text", Je.string newText ) ])
                , expect = Http.Detailed.expectJson GotSavedEdit todoDecoder
                , timeout = Nothing
                , tracker = Nothing
                }
            )



-- VIEW


view : Model -> H.Html Msg
view model =
    H.div []
        [ H.input [ Ha.placeholder "buy avacodos", Ha.value model.nextText, He.onInput ChangedNextText ] []
        , H.button [ He.onClick (PushedAddButton model.nextText) ] [ H.text "Add" ]
        , H.br [] []
        , viewLastError model.lastError
        , H.br [] []
        , Hl.lazy viewTodos model.todos
        ]


viewLastError : Maybe String -> H.Html Msg
viewLastError maybeErrStr =
    case maybeErrStr of
        Nothing ->
            H.text "No HTTP errors found :)"

        Just err ->
            H.text err


viewTodos : Array.Array Todo -> H.Html Msg
viewTodos todos =
    -- H.ul [] (List.map viewTodo (Array.toIndexedList todos))
    Hk.node "ul" [] (List.map viewKeyedTodo (Array.toIndexedList todos))


viewKeyedTodo : ( Index, Todo ) -> ( String, H.Html Msg )
viewKeyedTodo ( index, todo ) =
    -- ( String.fromInt todo.id ++ todo.editText, viewTodo ( index, todo ) )
    -- ( String.fromInt todo.id, viewTodo ( index, todo ) )
    -- TODO: why is this working?
    -- https://guide.elm-lang.org/optimization/keyed.html
    ( "key", viewTodo ( index, todo ) )


viewTodo : ( Index, Todo ) -> H.Html Msg
viewTodo ( index, todo ) =
    if todo.isEditing then
        H.li []
            [ H.button [ He.onClick (PushedCancelEdit index) ] [ H.text "Cancel Edit" ]
            , H.input [ Ha.placeholder "buy avacodos", Ha.value todo.editText, He.onInput (ChangedTodo index) ] []
            , H.button [ He.onClick (PushedSaveEdit todo.id todo.editText) ] [ H.text "Save edit" ]
            ]

    else
        H.li []
            [ H.button [ He.onClick (PushedDeleteTodo todo.id) ] [ H.text "Delete" ]
            , H.text todo.text
            , H.button [ He.onClick (PushedEdit index) ] [ H.text "Edit" ]
            ]


httpDetailedErrorBytesToStr : Http.Detailed.Error Bytes.Bytes -> String
httpDetailedErrorBytesToStr err =
    let
        start =
            "Server Error: "
    in
    case err of
        Http.Detailed.BadUrl str ->
            start ++ "BadUrl: " ++ str

        Http.Detailed.Timeout ->
            start ++ "Timeout"

        Http.Detailed.NetworkError ->
            start ++ "NetworkError"

        Http.Detailed.BadStatus metadata body ->
            start
                ++ "BadStatus: "
                ++ metadata.statusText
                ++ " : "
                ++ Maybe.withDefault "Undecodable bytes" (Bytes.Decode.decode sizedString body)

        Http.Detailed.BadBody metadata body str ->
            start
                ++ "BadBody: "
                ++ metadata.statusText
                ++ " : "
                ++ Maybe.withDefault "Undecodable bytes" (Bytes.Decode.decode sizedString body)
                ++ " : "
                ++ str


httpDetailedErrorStrToStr : Http.Detailed.Error String -> String
httpDetailedErrorStrToStr err =
    let
        start =
            "Server Error: "
    in
    case err of
        Http.Detailed.BadUrl str ->
            start ++ "BadUrl: " ++ str

        Http.Detailed.Timeout ->
            start ++ "Timeout"

        Http.Detailed.NetworkError ->
            start ++ "NetworkError"

        Http.Detailed.BadStatus metadata body ->
            start ++ "BadStatus: " ++ metadata.statusText ++ " : " ++ body

        Http.Detailed.BadBody metadata body str ->
            start ++ "BadBody: " ++ metadata.statusText ++ " : " ++ body ++ " : " ++ str



-- HTTP


todosDecoder : Jd.Decoder (List Todo)
todosDecoder =
    Jd.field "todos" (Jd.list todoDecoder)


todoDecoder : Jd.Decoder Todo
todoDecoder =
    Jd.map4 Todo
        (Jd.field "id" Jd.int)
        -- isEditing
        (Jd.succeed False)
        -- editText
        (Jd.succeed "")
        (Jd.field "text" Jd.string)
