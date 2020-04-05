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


type alias ErrorText =
    String


type alias Priority =
    Int


type alias TodoText =
    String


type alias PriorityText =
    String


type alias TodoInputExtensible r =
    { r
        | -- Gonna use this for input validation errors and server errors on submit
          -- I think that might be the right abstraction
          lastError : Maybe ErrorText
        , priorityText : PriorityText
        , text : TodoText
    }


emptyTodoInputExtensible : TodoInputExtensible r -> TodoInputExtensible r
emptyTodoInputExtensible todo =
    { todo
        | lastError = Nothing
        , priorityText = ""
        , text = ""
    }


type UpdatedTodoInput
    = ChangedPriorityText PriorityText
    | ChangedText TodoText
    | ChangedLastError (Maybe ErrorText)


updateTodoInputExtensible : UpdatedTodoInput -> TodoInputExtensible r -> TodoInputExtensible r
updateTodoInputExtensible msg todo =
    case msg of
        -- TODO: make this do validation on each keypress?
        ChangedPriorityText newPriorityText ->
            { todo | priorityText = newPriorityText }

        ChangedText newText ->
            { todo | text = newText }

        ChangedLastError newLastError ->
            { todo | lastError = newLastError }


{-| Embed me in the model
Note: not sure if this is needed. Can I pass TodoInputExtensible instead?
-}
type alias TodoToAdd =
    { priorityText : PriorityText, text : TodoText, lastError : Maybe ErrorText }


todoToAddToJson : TodoToAdd -> Result ErrorText Je.Value
todoToAddToJson todoToAdd =
    case String.toInt todoToAdd.priorityText of
        Nothing ->
            Err ("Cannot convert " ++ todoToAdd.priorityText ++ " to Int")

        Just priority ->
            Ok <|
                Je.object
                    [ ( "priority", Je.int priority )
                    , ( "text", Je.string todoToAdd.text )
                    ]


type alias TodoFromServer =
    { id : Id
    , priority : Priority
    , text : TodoText
    }


type alias TodoToEdit =
    { id : Id
    , index : Index
    , lastError : Maybe ErrorText
    , priorityText : PriorityText
    , text : TodoText
    }


todoToEditToJson : TodoToEdit -> Result ErrorText Je.Value
todoToEditToJson todoToEdit =
    -- NOTE: this turns out to be the same as todoToAddToJson, but I'm not sure if that will be true in the future
    -- I'd rather not abstract too early...
    case String.toInt todoToEdit.priorityText of
        Nothing ->
            Err ("Cannot convert " ++ todoToEdit.priorityText ++ " to Int")

        Just priority ->
            Ok <|
                Je.object
                    [ ( "priority", Je.int priority )
                    , ( "text", Je.string todoToEdit.text )
                    ]


type alias Model =
    { priorityText : PriorityText
    , text : TodoText
    , lastError : Maybe ErrorText
    , currentEdit : Maybe TodoToEdit
    , todos : Array.Array TodoFromServer
    }


init : () -> ( Model, Cmd Msg )
init _ =
    -- TODO: use an input box for this :)
    ( { priorityText = "1"
      , text = ""
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
      ChangedTodoToAdd UpdatedTodoInput
    | ChangedTodoToEdit UpdatedTodoInput
      -- Buttons Pressed
    | PressedAdd TodoToAdd
    | PressedCancelEdit
    | PressedDelete Id
    | PressedEdit Index TodoFromServer
    | PressedSaveEdit TodoToEdit
      -- Server Results
    | GotAddedNextText (Result (Http.Detailed.Error String) ( Http.Metadata, TodoFromServer ))
    | GotDeletedTodo Id (Result (Http.Detailed.Error Bytes.Bytes) ())
    | GotSavedEdit (Result (Http.Detailed.Error String) ( Http.Metadata, TodoFromServer ))
    | GotTodos (Result (Http.Detailed.Error String) ( Http.Metadata, List TodoFromServer ))


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
        ChangedTodoToAdd updateMsg ->
            ( updateTodoInputExtensible updateMsg model, Cmd.none )

        ChangedTodoToEdit updateMsg ->
            let
                newEdit =
                    model.currentEdit
                        |> Maybe.andThen
                            (\todoToEdit -> Just <| updateTodoInputExtensible updateMsg todoToEdit)
            in
            ( { model | currentEdit = newEdit }, Cmd.none )

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

        PressedAdd todoToAdd ->
            case todoToAddToJson todoToAdd of
                Ok jsonValue ->
                    -- TODO: empty on successfull HTTP result, not when submitting
                    ( emptyTodoInputExtensible model
                    , Http.request
                        { method = "POST"
                        , headers = []
                        , url = origin ++ "/api/items"
                        , body =
                            Http.jsonBody
                                jsonValue
                        , expect = Http.Detailed.expectJson GotAddedNextText todoDecoder
                        , timeout = Nothing
                        , tracker = Nothing
                        }
                    )

                Err errorText ->
                    ( updateTodoInputExtensible (ChangedLastError (Just errorText)) model, Cmd.none )

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

        PressedEdit index todoFromServer ->
            ( { model
                | currentEdit =
                    Just
                        { id = todoFromServer.id
                        , index = index
                        , priorityText = String.fromInt todoFromServer.priority
                        , text = todoFromServer.text
                        , lastError = Nothing
                        }
              }
            , Cmd.none
            )

        PressedSaveEdit todoToEdit ->
            case todoToEditToJson todoToEdit of
                Ok jsonValue ->
                    ( model
                    , Http.request
                        { method = "PATCH"
                        , headers = []
                        , url = origin ++ "/api/items/" ++ String.fromInt todoToEdit.id
                        , body = Http.jsonBody jsonValue
                        , expect = Http.Detailed.expectJson GotSavedEdit todoDecoder
                        , timeout = Nothing
                        , tracker = Nothing
                        }
                    )

                Err errorText ->
                    case model.currentEdit of
                        Just currentEdit ->
                            ( { model | currentEdit = Just { currentEdit | lastError = Just errorText } }, Cmd.none )

                        Nothing ->
                            ( model, Cmd.none )



-- VIEW


view : Model -> H.Html Msg
view model =
    H.div []
        [ H.input [ Ha.placeholder "0", Ha.value model.priorityText, He.onInput (ChangedTodoToAdd << ChangedPriorityText) ] []
        , H.input [ Ha.placeholder "buy avocados", Ha.value model.text, He.onInput (ChangedTodoToAdd << ChangedText) ] []
        , H.button [ He.onClick (PressedAdd { priorityText = model.priorityText, text = model.text, lastError = Nothing }) ] [ H.text "Add" ]
        , H.br [] []
        , viewLastError model.lastError
        , H.br [] []
        , Hl.lazy2 viewTodos model.currentEdit model.todos
        ]


viewLastError : Maybe ErrorText -> H.Html Msg
viewLastError maybeErrStr =
    H.text <| Maybe.withDefault "No errors found :)" maybeErrStr


viewTodos : Maybe TodoToEdit -> Array.Array TodoFromServer -> H.Html Msg
viewTodos currentEdit todos =
    -- Cache list items by key
    -- Curry argument here :) :D ;D
    Hk.ul [] (List.map (viewKeyedTodo currentEdit) (Array.toIndexedList todos))


viewKeyedTodo : Maybe TodoToEdit -> ( Index, TodoFromServer ) -> ( String, H.Html Msg )
viewKeyedTodo currentEdit ( index, todo ) =
    ( String.fromInt todo.id, Hl.lazy2 viewTodo currentEdit ( index, todo ) )


viewTodo : Maybe TodoToEdit -> ( Index, TodoFromServer ) -> H.Html Msg
viewTodo currentEdit ( index, todo ) =
    let
        notEditingNow =
            H.li []
                [ H.button [ He.onClick (PressedDelete todo.id) ] [ H.text "Delete" ]
                , H.text todo.text
                , H.button
                    [ He.onClick (PressedEdit index todo) ]
                    [ H.text "Edit" ]
                ]
    in
    case currentEdit of
        Nothing ->
            notEditingNow

        Just todoToEdit ->
            if todoToEdit.index == index then
                H.li []
                    [ H.button [ He.onClick PressedCancelEdit ] [ H.text "Cancel Edit" ]
                    , H.input
                        [ Ha.placeholder "0"
                        , Ha.value todoToEdit.priorityText
                        , He.onInput (ChangedTodoToEdit << ChangedPriorityText)
                        ]
                        []
                    , H.input
                        [ Ha.placeholder "buy avocados", Ha.value todoToEdit.text, He.onInput (ChangedTodoToEdit << ChangedText) ]
                        []
                    , H.button
                        [ He.onClick (PressedSaveEdit todoToEdit) ]
                        [ H.text "Save edit" ]
                    , viewLastError todoToEdit.lastError
                    ]

            else
                notEditingNow


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


todosDecoder : Jd.Decoder (List TodoFromServer)
todosDecoder =
    Jd.field "todos" (Jd.list todoDecoder)


todoDecoder : Jd.Decoder TodoFromServer
todoDecoder =
    Jd.map3 TodoFromServer
        (Jd.field "id" Jd.int)
        (Jd.field "priority" Jd.int)
        (Jd.field "text" Jd.string)
