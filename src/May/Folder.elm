module May.Folder exposing (Folder, decode, encode, id, name, new, rename)

import Json.Decode as D
import Json.Encode as E
import May.Id as Id exposing (Id)


type Folder
    = Folder (Id Folder) String


new : Id Folder -> String -> Folder
new newId newName =
    Folder newId newName


id : Folder -> Id Folder
id (Folder x _) =
    x


name : Folder -> String
name (Folder _ x) =
    x


rename : String -> Folder -> Folder
rename newName (Folder oldId _) =
    Folder oldId newName


encode : Folder -> E.Value
encode folder =
    E.object
        [ ( "id", Id.encode (id folder) )
        , ( "name", E.string (name folder) )
        ]


decode : D.Decoder Folder
decode =
    D.map2 Folder
        (D.field "id" Id.decode)
        (D.field "name" D.string)
