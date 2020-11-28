module May.Folder exposing (Folder, decode, encode, id, isSharing, name, new, rename, shareWith)

import Json.Decode as D
import Json.Encode as E
import May.Id as Id exposing (Id)


type Folder
    = Folder FolderInternal


type alias FolderInternal =
    { id_ : Id Folder
    , name_ : String
    , sharedWith_ : Maybe (List String)
    }


new : Id Folder -> String -> Folder
new newId newName =
    Folder
        { id_ = newId
        , name_ = newName
        , sharedWith_ = Nothing
        }


isSharing : Folder -> Bool
isSharing (Folder { sharedWith_ }) =
    sharedWith_ /= Nothing


shareWith : Maybe (List String) -> Folder -> Folder
shareWith newShare (Folder internal) =
    Folder { internal | sharedWith_ = newShare }


id : Folder -> Id Folder
id (Folder { id_ }) =
    id_


name : Folder -> String
name (Folder { name_ }) =
    name_


rename : String -> Folder -> Folder
rename newName (Folder internal) =
    Folder { internal | name_ = newName }


encode : Folder -> E.Value
encode folder =
    E.object
        [ ( "id", Id.encode (id folder) )
        , ( "name", E.string (name folder) )
        ]


decode : D.Decoder Folder
decode =
    D.map Folder <|
        D.map3 FolderInternal
            (D.field "id" Id.decode)
            (D.field "name" D.string)
            (D.maybe (D.field "sharedWith" (D.list D.string)))
