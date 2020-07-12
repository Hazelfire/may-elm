module May.Folder exposing
    ( Folder
    , generate
    , generateRoot
    , id
    , name
    , parentId
    , setName
    , view
    )

import Html exposing (Html, a, div, i, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import May.FolderId as FolderId exposing (FolderId)
import Random


type Folder
    = Folder
        { id : FolderId
        , name : String
        , parent : Maybe FolderId
        }


id : Folder -> FolderId
id (Folder folder) =
    folder.id


parentId : Folder -> Maybe FolderId
parentId (Folder folder) =
    folder.parent


{-| Views a folder card
-}
view : (FolderId -> msg) -> Folder -> Html msg
view clickHandler (Folder model) =
    a [ class "card", onClick (clickHandler model.id) ]
        [ div [ class "content" ]
            [ div [ class "header" ]
                [ i [ class "icon folder" ] []
                , text model.name
                ]
            ]
        ]


generateRoot : Random.Generator Folder
generateRoot =
    Random.map (\newid -> Folder { id = newid, name = "My Tasks", parent = Nothing }) FolderId.generate


generate : FolderId.FolderId -> Random.Generator Folder
generate pid =
    Random.map (\newid -> Folder { id = newid, name = "New Folder", parent = Just pid }) FolderId.generate


setName : String -> Folder -> Folder
setName newName (Folder folder) =
    Folder { folder | name = newName }


name : Folder -> String
name (Folder folder) =
    folder.name
