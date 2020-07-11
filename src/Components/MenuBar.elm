module Components.MenuBar exposing (main)

import Browser
import Html exposing (Html, div, text)
import Html.Attributes exposing (class)


type alias Model =
    ()


type alias Msg =
    ()


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> ( (), Cmd.none )
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


update : Msg -> Model -> ( Model, Cmd Msg )
update _ model =
    ( model, Cmd.none )


view : Model -> Html Msg
view _ =
    div [ class "ui top attached menu" ]
        [ div [ class "item" ] [ text "May" ]
        , div [ class "right menu" ]
            [ div [ class "item" ] [ text "Guest Mode" ]
            ]
        ]


subscriptions : Model -> Sub msg
subscriptions _ =
    Sub.none
