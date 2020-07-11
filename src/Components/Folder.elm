module Components.Folder exposing (Folder, viewFolder)

import Html exposing (Html, a, div, i, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)


type alias Folder =
    { id : String
    , name : String
    , parent : Maybe String
    }


{-| Views a folder card
-}
viewFolder : (String -> msg) -> Folder -> Html msg
viewFolder clickHandler model =
    a [ class "card", onClick (clickHandler model.id) ]
        [ div [ class "content" ]
            [ div [ class "header" ]
                [ i [ class "icon folder" ] []
                , text model.name
                ]
            ]
        ]
