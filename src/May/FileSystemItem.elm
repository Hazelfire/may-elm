module May.FileSystemItem exposing (FileSystemItem, id, map, name, parent, rename)

import May.Folder exposing (Folder)
import May.Id exposing (Id)


type FileSystemItem a
    = FileSystemItem
        { id : Id a
        , name : String
        , parent : Maybe (Id Folder)
        , item : a
        }


map : (a -> a) -> FileSystemItem a -> FileSystemItem a
map func (FileSystemItem fsi) =
    FileSystemItem { fsi | item = func fsi.item }


id : (a -> a) -> FileSystemItem a -> FileSystemItem a
id func (FileSystemItem fsi) =
    FileSystemItem { fsi | item = func fsi.item }


rename : FileSystemItem a -> String -> FileSystemItem a
rename (FileSystemItem fsi) newName =
    FileSystemItem <| { fsi | name = newName }


name : FileSystemItem a -> String
name (FileSystemItem fsi) =
    fsi.name


parent : FileSystemItem a -> Maybe (Id Folder)
parent (FileSystemItem fsi) =
    fsi.parent
