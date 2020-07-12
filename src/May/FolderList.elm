module May.FolderList exposing
    ( FolderList
    , addFolder
    , delete
    , folderWithId
    , foldersInFolder
    , foldersInFolderRecursive
    , getParent
    , new
    , setFolderName
    , tasksInFolder
    , tasksInFolderRecursive
    )

import May.Folder as Folder exposing (Folder)
import May.FolderId exposing (FolderId)
import May.Task as Task


type FolderList
    = FolderList (List Folder)


{-| Updates a product with a given name by a function
-}
conditionalMap : (a -> Bool) -> (a -> a) -> List a -> List a
conditionalMap cond func list =
    List.map
        (\x ->
            if cond x then
                func x

            else
                x
        )
        list


delete : FolderList -> FolderId -> FolderList
delete (FolderList folders) id =
    FolderList <| List.filter (Folder.id >> (/=) id) folders


new : List Folder.Folder -> FolderList
new folders =
    FolderList folders


{-| Gets all the folders in a directory
-}
foldersInFolder : FolderList -> FolderId -> List Folder
foldersInFolder (FolderList folders) parentId =
    List.filter (Folder.parentId >> (==) (Just parentId)) folders


{-| Gets all the folders in a directory recursively
-}
foldersInFolderRecursive : FolderList -> FolderId -> List Folder
foldersInFolderRecursive folders parentId =
    let
        subFolders =
            foldersInFolder folders parentId

        subFoldersId =
            List.map Folder.id subFolders
    in
    subFolders ++ List.concat (List.map (foldersInFolderRecursive folders) subFoldersId)


{-| Gets all the tasks in a directory
-}
tasksInFolder : List Task.Task -> FolderId -> List Task.Task
tasksInFolder tasks parentId =
    List.filter (Task.parent >> (==) parentId) tasks


{-| Gets all the tasks in a directory recursively
-}
tasksInFolderRecursive : FolderList -> List Task.Task -> FolderId -> List Task.Task
tasksInFolderRecursive folders tasks parentId =
    let
        subTasks =
            tasksInFolder tasks parentId

        subFolders =
            foldersInFolder folders parentId

        subFoldersId =
            List.map Folder.id subFolders
    in
    subTasks ++ List.concat (List.map (tasksInFolderRecursive folders tasks) subFoldersId)


folderWithId : FolderList -> FolderId -> Maybe Folder
folderWithId (FolderList folders) id =
    case List.filter (Folder.id >> (==) id) folders of
        x :: _ ->
            Just x

        _ ->
            Nothing


setFolderName : FolderList -> FolderId -> String -> FolderList
setFolderName (FolderList folders) id name =
    FolderList <| conditionalMap (Folder.id >> (==) id) (Folder.setName name) folders


getParent : FolderList -> FolderId -> Maybe FolderId
getParent folders folderId =
    folderWithId folders folderId
        |> Maybe.andThen Folder.parentId


addFolder : FolderList -> Folder -> FolderList
addFolder (FolderList folders) folder =
    FolderList <| (folder :: folders)
