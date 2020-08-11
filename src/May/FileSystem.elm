module May.FileSystem exposing
    ( FSUpdate
    , FileSystem
    , addFolder
    , addTask
    , allFolders
    , allTasks
    , decode
    , deleteFolder
    , deleteTask
    , emptySyncList
    , encode
    , folderParent
    , foldersInFolder
    , fsUpdateDecoder
    , getFolder
    , getRootId
    , getTask
    , mapOnFolder
    , mapOnTask
    , needsSync
    , new
    , syncList
    , taskParent
    , tasksInFolder
    , updateFS
    )

{-| This module uses a graph to represent all the types of relationships
you can have with tasks, labels etc

It also handles the updating of the file system from the backend.

-}

import Json.Decode as D
import Json.Encode as E
import May.Folder as Folder exposing (Folder)
import May.Id as Id exposing (Id)
import May.SyncList as SyncList exposing (SyncList)
import May.Task as Task exposing (Task)
import Time


{-| All the different types of nodes in the graph
Note that the folderNode is always garaunteed to have a parent. The root
folder is not stored as a node here, but in the filesystem object
-}
type Node
    = FolderNode FolderInfo
    | TaskNode TaskInfo


type alias FolderInfo =
    { parent : Id Folder
    , folder : Folder
    }


type alias TaskInfo =
    { parent : Id Folder
    , task : Task
    }


type FileSystem
    = FileSystem
        { nodes : List Node
        , root : Id Folder
        , syncList : SyncList
        }


findMaybe : (a -> Maybe b) -> List a -> Maybe b
findMaybe pred list =
    case list of
        x :: rest ->
            case pred x of
                Just y ->
                    Just y

                Nothing ->
                    findMaybe pred rest

        _ ->
            Nothing


filterJust : List (Maybe a) -> List a
filterJust list =
    case list of
        (Just x) :: rest ->
            x :: filterJust rest

        Nothing :: rest ->
            filterJust rest

        [] ->
            []


filterMaybe : (a -> Maybe b) -> List a -> List b
filterMaybe pred list =
    List.map pred list |> filterJust


addFolder : Id Folder -> Folder -> FileSystem -> FileSystem
addFolder parentId folder (FileSystem fs) =
    FileSystem
        { nodes = FolderNode { parent = parentId, folder = folder } :: fs.nodes
        , root = fs.root
        , syncList = SyncList.addNode (SyncList.SyncUpdateFolder parentId folder) fs.syncList
        }


addTask : Id Folder -> Task -> FileSystem -> FileSystem
addTask parentId task (FileSystem fs) =
    FileSystem
        { nodes = TaskNode { parent = parentId, task = task } :: fs.nodes
        , root = fs.root
        , syncList = SyncList.addNode (SyncList.SyncUpdateTask parentId task) fs.syncList
        }


getFolderInfo : Id Folder -> FileSystem -> Maybe FolderInfo
getFolderInfo folderId (FileSystem fs) =
    findMaybe
        (\x ->
            case x of
                FolderNode info ->
                    if Folder.id info.folder == folderId then
                        Just info

                    else
                        Nothing

                TaskNode _ ->
                    Nothing
        )
        fs.nodes


getTaskInfo : Id Task -> FileSystem -> Maybe TaskInfo
getTaskInfo taskId (FileSystem fs) =
    findMaybe
        (\x ->
            case x of
                TaskNode info ->
                    if Task.id info.task == taskId then
                        Just info

                    else
                        Nothing

                _ ->
                    Nothing
        )
        fs.nodes


getFolder : Id Folder -> FileSystem -> Maybe Folder
getFolder folderId fs =
    getFolderInfo folderId fs
        |> Maybe.map .folder


getTask : Id Task -> FileSystem -> Maybe Task
getTask taskId fs =
    getTaskInfo taskId fs |> Maybe.map .task


new : Folder -> FileSystem
new folder =
    FileSystem { nodes = [], root = Folder.id folder, syncList = SyncList.empty }


folderParent : Id Folder -> FileSystem -> Maybe (Id Folder)
folderParent folderId fs =
    getFolderInfo folderId fs |> Maybe.map .parent


taskParent : Id Task -> FileSystem -> Maybe (Id Folder)
taskParent taskId fs =
    getTaskInfo taskId fs |> Maybe.map .parent


foldersInFolder : Id Folder -> FileSystem -> List Folder
foldersInFolder folderId (FileSystem fs) =
    filterMaybe
        (\x ->
            case x of
                FolderNode info ->
                    if info.parent == folderId then
                        Just info.folder

                    else
                        Nothing

                _ ->
                    Nothing
        )
        fs.nodes


tasksInFolder : Id Folder -> FileSystem -> List Task
tasksInFolder taskId (FileSystem fs) =
    filterMaybe
        (\x ->
            case x of
                TaskNode info ->
                    if info.parent == taskId then
                        Just info.task

                    else
                        Nothing

                _ ->
                    Nothing
        )
        fs.nodes


mapOnFolder : Id Folder -> (Folder -> Folder) -> FileSystem -> FileSystem
mapOnFolder folderId mapFunc (FileSystem fs) =
    case fs.nodes of
        [] ->
            FileSystem fs

        x :: rest ->
            let
                (FileSystem restFs) =
                    mapOnFolder folderId mapFunc (FileSystem { fs | nodes = rest })
            in
            case x of
                FolderNode info ->
                    if Folder.id info.folder == folderId then
                        let
                            newFolder =
                                mapFunc info.folder
                        in
                        FileSystem { restFs | nodes = FolderNode { info | folder = newFolder } :: restFs.nodes, syncList = SyncList.addNode (SyncList.SyncUpdateFolder info.parent newFolder) restFs.syncList }

                    else
                        FileSystem { restFs | nodes = FolderNode info :: restFs.nodes }

                a ->
                    FileSystem { restFs | nodes = a :: restFs.nodes }


mapOnTask : Id Task -> (Task -> Task) -> FileSystem -> FileSystem
mapOnTask taskId mapFunc (FileSystem fs) =
    case fs.nodes of
        [] ->
            FileSystem fs

        x :: rest ->
            let
                (FileSystem restFs) =
                    mapOnTask taskId mapFunc (FileSystem { fs | nodes = rest })
            in
            case x of
                TaskNode info ->
                    if Task.id info.task == taskId then
                        let
                            newTask =
                                mapFunc info.task
                        in
                        FileSystem { restFs | nodes = TaskNode { info | task = newTask } :: restFs.nodes, syncList = SyncList.addNode (SyncList.SyncUpdateTask info.parent newTask) restFs.syncList }

                    else
                        FileSystem { restFs | nodes = TaskNode info :: restFs.nodes }

                a ->
                    FileSystem { restFs | nodes = a :: restFs.nodes }


allTaskDetails : FileSystem -> List TaskInfo
allTaskDetails (FileSystem fs) =
    filterMaybe
        (\x ->
            case x of
                TaskNode info ->
                    Just info

                _ ->
                    Nothing
        )
        fs.nodes


allTasks : FileSystem -> List Task
allTasks fs =
    List.map .task <| allTaskDetails fs


allFolders : FileSystem -> List Folder
allFolders fs =
    List.map .folder <| allFolderDetails fs


allFolderDetails : FileSystem -> List FolderInfo
allFolderDetails (FileSystem fs) =
    filterMaybe
        (\x ->
            case x of
                FolderNode info ->
                    Just info

                _ ->
                    Nothing
        )
        fs.nodes


encode : FileSystem -> E.Value
encode (FileSystem fs) =
    E.object
        [ ( "tasks", E.list encodeTaskNode (allTaskDetails (FileSystem fs)) )
        , ( "folders", E.list encodeFolderNode (allFolderDetails (FileSystem fs)) )
        , ( "root", Id.encode fs.root )
        , ( "synclist", SyncList.encode fs.syncList )
        ]


encodeTaskNode : TaskInfo -> E.Value
encodeTaskNode info =
    let
        fields =
            [ ( "name", E.string (Task.name info.task) )
            , ( "duration", E.float (Task.duration info.task) )
            , ( "id", Id.encode (Task.id info.task) )
            , ( "pid", Id.encode info.parent )
            ]
    in
    case Task.due info.task of
        Just dueDate ->
            E.object (( "due", E.int (Time.posixToMillis dueDate) ) :: fields)

        Nothing ->
            E.object fields


encodeFolderNode : FolderInfo -> E.Value
encodeFolderNode info =
    E.object
        [ ( "id", Id.encode (Folder.id info.folder) )
        , ( "name", E.string (Folder.name info.folder) )
        , ( "pid", Id.encode info.parent )
        ]


decodeTaskNode : D.Decoder Node
decodeTaskNode =
    Task.decode
        |> D.andThen
            (\task ->
                D.field "pid" Id.decode
                    |> D.andThen
                        (\pid ->
                            D.succeed (TaskNode { parent = pid, task = task })
                        )
            )


decodeFolderNode : D.Decoder Node
decodeFolderNode =
    Folder.decode
        |> D.andThen
            (\folder ->
                D.field "pid" Id.decode
                    |> D.andThen
                        (\pid ->
                            D.succeed (FolderNode { parent = pid, folder = folder })
                        )
            )


decode : D.Decoder FileSystem
decode =
    D.map4
        (\tasks folders root synclist ->
            FileSystem
                { nodes = folders ++ tasks
                , root = root
                , syncList = synclist
                }
        )
        (D.field "tasks" (D.list decodeTaskNode))
        (D.field "folders" (D.list decodeFolderNode))
        (D.field "root" Id.decode)
        (D.field "synclist" SyncList.decode)


deleteFolder : Id Folder -> FileSystem -> FileSystem
deleteFolder fid fs =
    let
        folderChildIds =
            foldersInFolderRecursive fid fs

        taskChildIds =
            tasksInFolderRecursive fid fs

        foldersDeleted =
            deleteFolders_ (fid :: folderChildIds) fs

        tasksDeleted =
            deleteTasks_ taskChildIds foldersDeleted

        syncNodeIds =
            List.map SyncList.SyncFolderId (fid :: folderChildIds) ++ List.map SyncList.SyncTaskId taskChildIds

        (FileSystem inner) =
            tasksDeleted

        removedSyncList =
            FileSystem { inner | syncList = applyAll (List.map SyncList.deleteNode syncNodeIds) inner.syncList }
    in
    removedSyncList


applyAll : List (a -> a) -> a -> a
applyAll list x =
    case list of
        f :: rest ->
            applyAll rest (f x)

        [] ->
            x


deleteTask : Id Task -> FileSystem -> FileSystem
deleteTask tid fs =
    let
        deletedTasks =
            deleteTasks_ [ tid ] fs

        (FileSystem inner) =
            deletedTasks
    in
    FileSystem { inner | syncList = SyncList.deleteNode (SyncList.SyncTaskId tid) inner.syncList }


foldersInFolderRecursive : Id Folder -> FileSystem -> List (Id Folder)
foldersInFolderRecursive fid fs =
    let
        children =
            List.map Folder.id (foldersInFolder fid fs)
    in
    children ++ List.concat (List.map (\x -> foldersInFolderRecursive x fs) children)


tasksInFolderRecursive : Id Folder -> FileSystem -> List (Id Task)
tasksInFolderRecursive fid fs =
    let
        childrenFolder =
            List.map Folder.id (foldersInFolder fid fs)

        taskChildren =
            List.map Task.id (tasksInFolder fid fs)
    in
    taskChildren ++ List.concat (List.map (\x -> tasksInFolderRecursive x fs) childrenFolder)


deleteTasks_ : List (Id Task) -> FileSystem -> FileSystem
deleteTasks_ tids (FileSystem fs) =
    case tids of
        [] ->
            FileSystem fs

        x :: rest ->
            let
                newFS =
                    FileSystem
                        { fs
                            | nodes =
                                filterMaybe
                                    (\node ->
                                        case node of
                                            TaskNode info ->
                                                if Task.id info.task == x then
                                                    Nothing

                                                else
                                                    Just (TaskNode info)

                                            a ->
                                                Just a
                                    )
                                    fs.nodes
                        }
            in
            deleteTasks_ rest newFS


deleteFolders_ : List (Id Folder) -> FileSystem -> FileSystem
deleteFolders_ fids (FileSystem fs) =
    case fids of
        [] ->
            FileSystem fs

        x :: rest ->
            let
                newFS =
                    FileSystem
                        { fs
                            | nodes =
                                filterMaybe
                                    (\node ->
                                        case node of
                                            FolderNode info ->
                                                if Folder.id info.folder == x then
                                                    Nothing

                                                else
                                                    Just (FolderNode info)

                                            a ->
                                                Just a
                                    )
                                    fs.nodes
                        }
            in
            deleteFolders_ rest newFS


getRootId : FileSystem -> Id Folder
getRootId (FileSystem fs) =
    fs.root


{-| An FSUpdate is an update to the current system
-}
type FSUpdate
    = FSUpdate (List Node)


fsUpdateDecoder : D.Decoder FSUpdate
fsUpdateDecoder =
    D.map FSUpdate (D.list nodeDecoder)


nodeDecoder : D.Decoder Node
nodeDecoder =
    D.field "type" D.string
        |> D.andThen
            (\type_ ->
                case type_ of
                    "folder" ->
                        decodeFolderNode

                    "task" ->
                        decodeTaskNode

                    _ ->
                        D.fail "Invalid node type"
            )


updateFS : FSUpdate -> FileSystem -> FileSystem
updateFS (FSUpdate update) (FileSystem fs) =
    FileSystem { fs | nodes = update ++ fs.nodes }


needsSync : FileSystem -> Bool
needsSync (FileSystem fs) =
    SyncList.needsSync fs.syncList


syncList : FileSystem -> SyncList
syncList (FileSystem fs) =
    fs.syncList


emptySyncList : FileSystem -> FileSystem
emptySyncList (FileSystem fs) =
    FileSystem { fs | syncList = SyncList.empty }
