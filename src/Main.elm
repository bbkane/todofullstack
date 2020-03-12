module Main exposing (..)

import Array
import Browser
import Bytes
import Bytes.Decode
import Html as H
import Html.Attributes as Ha
import Html.Events as He
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
        , subscriptions = subscriptions
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

    -- Puttung the last error as a field. If there's a network error I still want
    -- to see the last version of the list (so don't put this as a Result in todos)
    -- TODO: make this a Maybe String so I can put all errors here to display to the user
    , lastError : Maybe (Http.Detailed.Error String)
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


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ChangedNextText t ->
            ( { model | nextText = t }, Cmd.none )

        ChangedTodo index newEditText ->
            let
                todoMaybe =
                    Array.get index model.todos
            in
            case todoMaybe of
                Nothing ->
                    ( model, Cmd.none )

                Just todo ->
                    ( { model
                        | todos =
                            Array.set index { todo | editText = newEditText } model.todos
                      }
                    , Cmd.none
                    )

        GotAddedNextText result ->
            case result of
                Ok ( _, todo ) ->
                    ( { model | todos = Array.push todo model.todos }, Cmd.none )

                Err err ->
                    ( { model | lastError = Just err }, Cmd.none )

        GotDeletedTodo id result ->
            -- TODO: Actually delete from stored array
            case result of
                Ok _ ->
                    ( model, Cmd.none )

                Err err ->
                    -- Convert to string :)
                    let
                        sizedString : Bytes.Decode.Decoder String
                        sizedString =
                            Bytes.Decode.unsignedInt32 Bytes.BE
                                |> Bytes.Decode.andThen Bytes.Decode.string

                        -- TODO: put in own function
                        newError : Maybe (Http.Detailed.Error String)
                        newError =
                            case err of
                                Http.Detailed.BadUrl s ->
                                    Just <| Http.Detailed.BadUrl s

                                Http.Detailed.Timeout ->
                                    Just Http.Detailed.Timeout

                                Http.Detailed.NetworkError ->
                                    Just Http.Detailed.NetworkError

                                Http.Detailed.BadStatus metadata bodyBytes ->
                                    let
                                        errStr =
                                            Maybe.withDefault
                                                "Could not decode bytes"
                                                -- TODO: wish I knew how to decode bytes here
                                                (Bytes.Decode.decode sizedString bodyBytes)
                                    in
                                    Just <| Http.Detailed.BadStatus metadata errStr

                                Http.Detailed.BadBody metadata bodyBytes str ->
                                    let
                                        errStr =
                                            Maybe.withDefault
                                                "Could not decode bytes"
                                                -- TODO: wish I knew how to decode bytes here
                                                (Bytes.Decode.decode sizedString bodyBytes)
                                    in
                                    Just <| Http.Detailed.BadBody metadata errStr str
                    in
                    ( { model | lastError = newError }, Cmd.none )

        GotTodos result ->
            case result of
                Ok ( _, todos ) ->
                    ( { model | todos = Array.fromList todos }, Cmd.none )

                Err err ->
                    ( { model | lastError = Just err }, Cmd.none )

        GotSavedEdit result ->
            case result of
                Ok ( _, todo ) ->
                    let
                        maybeIndex =
                            findIndex (\i -> i.id == todo.id) model.todos
                    in
                    case maybeIndex of
                        Just index ->
                            ( { model | todos = Array.set index todo model.todos }, Cmd.none )

                        Nothing ->
                            ( model, Cmd.none )

                Err err ->
                    ( { model | lastError = Just err }, Cmd.none )

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
            let
                todoMaybe =
                    Array.get index model.todos
            in
            case todoMaybe of
                Nothing ->
                    ( model, Cmd.none )

                Just todo ->
                    ( { model
                        | todos =
                            Array.set index { todo | isEditing = False, editText = "" } model.todos
                      }
                    , Cmd.none
                    )

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
            let
                todoMaybe =
                    Array.get index model.todos
            in
            case todoMaybe of
                Nothing ->
                    ( model, Cmd.none )

                Just todo ->
                    ( { model
                        | todos = Array.set index { todo | isEditing = True, editText = todo.text } model.todos
                      }
                    , Cmd.none
                    )

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
        , viewTodos model.todos
        ]


viewLastError : Maybe (Http.Detailed.Error String) -> H.Html Msg
viewLastError maybeErr =
    case maybeErr of
        Nothing ->
            H.text "No HTTP errors found :)"

        Just err ->
            H.text (httpDetailedErrorToStr err)


httpDetailedErrorToStr : Http.Detailed.Error String -> String
httpDetailedErrorToStr err =
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


viewTodos : Array.Array Todo -> H.Html Msg
viewTodos todos =
    -- H.ul [] (Array.toIndexedList (Array.map (\t -> viewTodo t) todos))
    H.ul [] (List.map (\li -> viewTodo li) (Array.toIndexedList todos))


viewTodo : ( Int, Todo ) -> H.Html Msg
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



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
