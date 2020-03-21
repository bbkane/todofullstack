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


main : Program () Model Msg
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


{-| Local position of todo in todos
-}
type alias Index =
    Int


{-| opaque id from server for a todo.
each todo has a unique id
-}
type alias Id =
    Int


type alias TodoText =
    String


type alias ErrorText =
    String


type alias Todo =
    { id : Id
    , text : TodoText
    }


type alias Model =
    { nextText : TodoText
    , lastError : Maybe ErrorText
    , currentEdit : Maybe { index : Index, text : TodoText }
    , todos : Array.Array Todo
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { nextText = ""
      , lastError = Nothing
      , currentEdit = Nothing
      , todos = Array.empty
      }
    , Http.get
        { url = origin ++ "/api/items"
        , expect = Http.Detailed.expectJson GotTodos todosDecoder
        }
    )



-- UPDATE


type Msg
    = -- Changes to inputs
      ChangedNextText TodoText
    | ChangedTodo Index TodoText
      -- Buttons Pressed
    | PressedAdd TodoText
    | PressedCancelEdit
    | PressedDelete Id
    | PressedEdit Index TodoText
    | PressedSaveEdit Id TodoText
      -- Server Results
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


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ChangedNextText t ->
            ( { model | nextText = t }, Cmd.none )

        ChangedTodo index newEditText ->
            ( { model | currentEdit = Just { index = index, text = newEditText } }, Cmd.none )

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
                            ( { model | todos = Array.set index todo model.todos, currentEdit = Nothing }, Cmd.none )

                        Nothing ->
                            ( model, Cmd.none )

                Err err ->
                    ( { model | lastError = Just <| httpDetailedErrorStrToStr err }, Cmd.none )

        PressedAdd t ->
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

        PressedCancelEdit ->
            ( { model | currentEdit = Nothing }, Cmd.none )

        PressedDelete id ->
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

        PressedEdit index editText ->
            ( { model | currentEdit = Just { index = index, text = editText } }, Cmd.none )

        PressedSaveEdit id newText ->
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
        , H.button [ He.onClick (PressedAdd model.nextText) ] [ H.text "Add" ]
        , H.br [] []
        , viewLastError model.lastError
        , H.br [] []
        , Hl.lazy2 viewTodos model.currentEdit model.todos
        ]


viewLastError : Maybe ErrorText -> H.Html Msg
viewLastError maybeErrStr =
    -- TODO: Maybe.withDefault here :)
    case maybeErrStr of
        Nothing ->
            H.text "No errors found :)"

        Just err ->
            H.text err


viewTodos : Maybe { index : Index, text : TodoText } -> Array.Array Todo -> H.Html Msg
viewTodos currentEdit todos =
    Hk.ul [] (List.map (viewKeyedTodo currentEdit) (Array.toIndexedList todos))


viewKeyedTodo : Maybe { index : Index, text : TodoText } -> ( Index, Todo ) -> ( String, H.Html Msg )
viewKeyedTodo currentEdit ( index, todo ) =
    ( String.fromInt todo.id, viewTodo currentEdit ( index, todo ) )


viewTodo : Maybe { index : Index, text : TodoText } -> ( Index, Todo ) -> H.Html Msg
viewTodo currentEdit ( index, todo ) =
    case currentEdit of
        Nothing ->
            H.li []
                [ H.button [ He.onClick (PressedDelete todo.id) ] [ H.text "Delete" ]
                , H.text todo.text
                , H.button [ He.onClick (PressedEdit index todo.text) ] [ H.text "Edit" ]
                ]

        Just inner ->
            if inner.index == index then
                H.li []
                    [ H.button [ He.onClick PressedCancelEdit ] [ H.text "Cancel Edit" ]
                    , H.input [ Ha.placeholder "buy avacodos", Ha.value inner.text, He.onInput (ChangedTodo index) ] []
                    , H.button [ He.onClick (PressedSaveEdit todo.id inner.text) ] [ H.text "Save edit" ]
                    ]

            else
                H.li []
                    [ H.button [ He.onClick (PressedDelete todo.id) ] [ H.text "Delete" ]
                    , H.text todo.text
                    , H.button [ He.onClick (PressedEdit index todo.text) ] [ H.text "Edit" ]
                    ]


sizedString : Bytes.Decode.Decoder String
sizedString =
    Bytes.Decode.unsignedInt32 Bytes.BE
        |> Bytes.Decode.andThen Bytes.Decode.string


httpDetailedErrorBytesToStr : Http.Detailed.Error Bytes.Bytes -> ErrorText
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


httpDetailedErrorStrToStr : Http.Detailed.Error String -> ErrorText
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
    Jd.map2 Todo
        (Jd.field "id" Jd.int)
        (Jd.field "text" Jd.string)
