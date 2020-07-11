port module Components.Folder exposing (main)

import Browser
import Html exposing (Html, a, div, i, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)


type alias Model =
    Folder


type alias Folder =
    { id : String
    , name : String
    , parent : String
    }


type alias Action =
    { type_ : String
    , folder : Folder
    }


type Msg
    = Dispatch Action
    | SetState Model


port dispatch : Action -> Cmd msg


port setState : (Model -> msg) -> Sub msg


main : Program Model Model Msg
main =
    Browser.element
        { init = \model -> ( model, Cmd.none )
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        Dispatch action ->
            ( model, dispatch action )

        SetState new_model ->
            ( new_model, Cmd.none )


view : Model -> Html Msg
view model =
    div [ class "card" ]
        [ div [ class "content" ]
            [ a [ class "header", onClick (Dispatch { type_ = "SET_FOLDER", folder = model }) ]
                [ i [ class "icon folder" ] []
                , text model.name
                ]
            ]
        ]


subscriptions : Model -> Sub Msg
subscriptions _ =
    setState SetState
