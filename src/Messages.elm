module Messages exposing (EditFolderMsg(..), Msg(..))


type Msg
    = NewFolder String
    | CreateFolder
    | SetFolder String
    | EditFolder EditFolderMsg
    | DeleteCurrentFolder


type EditFolderMsg
    = StartEditFolderName
    | SetFolderName
    | ChangeFolderName String
    | EditKeyDown Int
