module Main exposing (..)

import Array
import Browser
import Html as H
import Html.Attributes as Ha
import Html.Events as He
import Http
import Http.Detailed
import Json.Decode as Jd
import Json.Encode as Je
import List



-- Useful when using commands and subscriptions
-- MAIN


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


origin =
    "http://localhost:5000"


type alias Todo =
    { id : Int
    , editText : String
    , text : String
    }


type alias Model =
    { nextText : String

    -- Puttung the last error as a field. If there's a network error I still want
    -- to see the last version of the list (so don't put this as a Result in todos)
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



-- UPDATE


type Msg
    = AddedNextText String
    | GotAddedNextText (Result (Http.Detailed.Error String) ( Http.Metadata, Todo ))
    | GotTodos (Result (Http.Detailed.Error String) ( Http.Metadata, List Todo ))
    | ChangedNextText String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        AddedNextText t ->
            ( { model | nextText = "" }
            , Http.request
                { method = "PATCH"
                , headers = []
                , url = origin ++ "/api/items"
                , body = Http.jsonBody (Je.object [ ( "text", Je.string t ) ])
                , expect = Http.Detailed.expectJson GotAddedNextText todoDecoder
                , timeout = Nothing
                , tracker = Nothing
                }
            )

        ChangedNextText t ->
            ( { model | nextText = t }, Cmd.none )

        GotAddedNextText result ->
            case result of
                Ok ( _, todo ) ->
                    ( { model | todos = Array.push todo model.todos }, Cmd.none )

                Err err ->
                    ( { model | lastError = Just err }, Cmd.none )

        GotTodos result ->
            case result of
                Ok ( _, todos ) ->
                    ( { model | todos = Array.fromList todos }, Cmd.none )

                Err err ->
                    ( { model | lastError = Just err }, Cmd.none )



-- VIEW


view : Model -> H.Html Msg
view model =
    H.div []
        [ H.input [ Ha.placeholder "buy avacodos", Ha.value model.nextText, He.onInput ChangedNextText ] []
        , H.button [ He.onClick (AddedNextText model.nextText) ] [ H.text "Add" ]
        ]


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



-- HTTP


todosDecoder : Jd.Decoder (List Todo)
todosDecoder =
    Jd.field "todos" (Jd.list todoDecoder)


todoDecoder : Jd.Decoder Todo
todoDecoder =
    Jd.map3 Todo
        (Jd.field "id" Jd.int)
        -- editText
        (Jd.succeed "")
        (Jd.field "text" Jd.string)



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
