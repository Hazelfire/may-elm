module May.Folder exposing (Folder, decode, encode, id, name, new, rename, share, shareKey)

import Json.Decode as D
import Json.Encode as E
import May.Id as Id exposing (Id)


type Folder
    = Folder FolderInternal


type alias FolderInternal =
    { id_ : Id Folder
    , name_ : String
    , shareKey_ : Maybe String
    }


new : Id Folder -> String -> Folder
new newId newName =
    Folder
        { id_ = newId
        , name_ = newName
        , shareKey_ = Nothing
        }


shareKey : Folder -> Maybe String
shareKey (Folder { shareKey_ }) =
    shareKey_


share : Maybe String -> Folder -> Folder
share newShare (Folder internal) =
    Folder { internal | shareKey_ = newShare }


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
            (D.maybe (D.field "shareKey" D.string))
