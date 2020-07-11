module Components.FolderHeader exposing (main)

import Browser
import Html exposing (Html, span, text)
import Html.Attributes exposing (class)


type alias Model =
    { name : String }


type alias Msg =
    ()


type alias Flags =
    { name : String }


main : Program Flags Model Msg
main =
    Browser.element
        { init = \x -> ( x, Cmd.none )
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


update : Msg -> Model -> ( Model, Cmd Msg )
update _ model =
    ( model, Cmd.none )


view : Model -> Html Msg
view model =
    span [] [ text model.name ]


subscriptions : Model -> Sub msg
subscriptions _ =
    Sub.none
