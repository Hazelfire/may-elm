module May.FileSystem exposing
    ( FileSystem
    , addFolder
    , addTask
    , allFolders
    , allTasks
    , decode
    , deleteFolder
    , deleteTask
    , encode
    , folderParent
    , foldersInFolder
    , getFolder
    , getRootId
    , getTask
    , mapOnFolder
    , mapOnTask
    , new
    , taskParent
    , tasksInFolder
    )

{-| This module uses a graph to represent all the types of relationships
you can have with tasks, labels etc
-}

import Json.Decode as D
import Json.Encode as E
import May.Folder as Folder exposing (Folder)
import May.Id as Id exposing (Id)
import May.Task as Task exposing (Task)


{-| All the relationships in the graph
-}
type Edge
    = ParentOfTask (Id Folder) (Id Task)
    | ParentOfFolder (Id Folder) (Id Folder)


{-| All the different types of nodes in the graph
-}
type Node
    = FolderNode Folder
    | TaskNode Task


type FileSystem
    = FileSystem
        { nodes : List Node
        , edges : List Edge
        , root : Id Folder
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
        { nodes = FolderNode folder :: fs.nodes
        , edges = ParentOfFolder parentId (Folder.id folder) :: fs.edges
        , root = fs.root
        }


addTask : Id Folder -> Task -> FileSystem -> FileSystem
addTask parentId task (FileSystem fs) =
    FileSystem
        { nodes = TaskNode task :: fs.nodes
        , edges = ParentOfTask parentId (Task.id task) :: fs.edges
        , root = fs.root
        }


getFolder : Id Folder -> FileSystem -> Maybe Folder
getFolder folderId (FileSystem fs) =
    findMaybe
        (\x ->
            case x of
                FolderNode node ->
                    if Folder.id node == folderId then
                        Just node

                    else
                        Nothing

                TaskNode _ ->
                    Nothing
        )
        fs.nodes


getTask : Id Task -> FileSystem -> Maybe Task
getTask taskId (FileSystem fs) =
    findMaybe
        (\x ->
            case x of
                TaskNode node ->
                    if Task.id node == taskId then
                        Just node

                    else
                        Nothing

                _ ->
                    Nothing
        )
        fs.nodes


new : Folder -> FileSystem
new folder =
    FileSystem { nodes = [ FolderNode folder ], edges = [], root = Folder.id folder }


folderParent : Id Folder -> FileSystem -> Maybe (Id Folder)
folderParent folderId (FileSystem fs) =
    findMaybe
        (\x ->
            case x of
                ParentOfFolder pid fid ->
                    if fid == folderId then
                        Just pid

                    else
                        Nothing

                _ ->
                    Nothing
        )
        fs.edges


taskParent : Id Task -> FileSystem -> Maybe (Id Folder)
taskParent taskId (FileSystem fs) =
    findMaybe
        (\x ->
            case x of
                ParentOfTask pid fid ->
                    if fid == taskId then
                        Just pid

                    else
                        Nothing

                _ ->
                    Nothing
        )
        fs.edges


foldersInFolder : Id Folder -> FileSystem -> List (Id Folder)
foldersInFolder folderId (FileSystem fs) =
    filterMaybe
        (\x ->
            case x of
                ParentOfFolder pid fid ->
                    if pid == folderId then
                        Just fid

                    else
                        Nothing

                _ ->
                    Nothing
        )
        fs.edges


tasksInFolder : Id Folder -> FileSystem -> List (Id Task)
tasksInFolder folderId (FileSystem fs) =
    filterMaybe
        (\x ->
            case x of
                ParentOfTask pid tid ->
                    if pid == folderId then
                        Just tid

                    else
                        Nothing

                _ ->
                    Nothing
        )
        fs.edges


mapOnFolder : Id Folder -> (Folder -> Folder) -> FileSystem -> FileSystem
mapOnFolder folderId mapFunc (FileSystem fs) =
    let
        newNodes =
            List.map
                (\x ->
                    case x of
                        FolderNode folder ->
                            if Folder.id folder == folderId then
                                FolderNode <| mapFunc folder

                            else
                                FolderNode <| folder

                        a ->
                            a
                )
                fs.nodes
    in
    FileSystem { fs | nodes = newNodes }


mapOnTask : Id Task -> (Task -> Task) -> FileSystem -> FileSystem
mapOnTask taskId mapFunc (FileSystem fs) =
    let
        newNodes =
            List.map
                (\x ->
                    case x of
                        TaskNode task ->
                            if Task.id task == taskId then
                                TaskNode <| mapFunc task

                            else
                                TaskNode task

                        a ->
                            a
                )
                fs.nodes
    in
    FileSystem { fs | nodes = newNodes }


allTasks : FileSystem -> List Task
allTasks (FileSystem fs) =
    filterMaybe
        (\x ->
            case x of
                TaskNode task ->
                    Just task

                _ ->
                    Nothing
        )
        fs.nodes


allFolders : FileSystem -> List Folder
allFolders (FileSystem fs) =
    filterMaybe
        (\x ->
            case x of
                FolderNode folder ->
                    Just folder

                _ ->
                    Nothing
        )
        fs.nodes


encode : FileSystem -> E.Value
encode (FileSystem fs) =
    E.object
        [ ( "tasks", E.list Task.encode (allTasks (FileSystem fs)) )
        , ( "folders", E.list Folder.encode (allFolders (FileSystem fs)) )
        , ( "root", Id.encode fs.root )
        , ( "edges", E.list encodeEdge fs.edges )
        ]


encodeEdge : Edge -> E.Value
encodeEdge edge =
    case edge of
        ParentOfFolder from to ->
            E.object [ ( "type", E.string "ParentOfFolder" ), ( "from", Id.encode from ), ( "to", Id.encode to ) ]

        ParentOfTask from to ->
            E.object [ ( "type", E.string "ParentOfTask" ), ( "from", Id.encode from ), ( "to", Id.encode to ) ]


decode : D.Decoder FileSystem
decode =
    D.map4
        (\tasks folders edges root ->
            FileSystem
                { nodes = List.map FolderNode folders ++ List.map TaskNode tasks
                , edges = edges
                , root = root
                }
        )
        (D.field "tasks" (D.list Task.decode))
        (D.field "folders" (D.list Folder.decode))
        (D.field "edges" (D.list decodeEdge))
        (D.field "root" Id.decode)


decodeEdge : D.Decoder Edge
decodeEdge =
    D.field "type" D.string
        |> D.andThen
            (\type_ ->
                if type_ == "ParentOfFolder" then
                    D.map2 ParentOfFolder
                        (D.field "from" Id.decode)
                        (D.field "to" Id.decode)

                else
                    D.map2 ParentOfTask
                        (D.field "from" Id.decode)
                        (D.field "to" Id.decode)
            )


applyAll : List (a -> a) -> a -> a
applyAll updates init =
    case updates of
        a :: rest ->
            applyAll rest (a init)

        [] ->
            init


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

        folderEdgesDeleted =
            applyAll (List.map deleteFolderEdges (fid :: folderChildIds)) tasksDeleted

        taskEdgesDeleted =
            applyAll (List.map deleteTaskEdges taskChildIds) folderEdgesDeleted
    in
    taskEdgesDeleted


deleteTask : Id Task -> FileSystem -> FileSystem
deleteTask tid fs =
    let
        taskEdgesDeleted =
            deleteTaskEdges tid fs
    in
    deleteTasks_ [ tid ] taskEdgesDeleted


foldersInFolderRecursive : Id Folder -> FileSystem -> List (Id Folder)
foldersInFolderRecursive fid fs =
    let
        children =
            foldersInFolder fid fs
    in
    children ++ List.concat (List.map (\x -> foldersInFolderRecursive x fs) children)


tasksInFolderRecursive : Id Folder -> FileSystem -> List (Id Task)
tasksInFolderRecursive fid fs =
    let
        childrenFolder =
            foldersInFolder fid fs

        taskChildren =
            tasksInFolder fid fs
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
                                            TaskNode task ->
                                                if Task.id task == x then
                                                    Nothing

                                                else
                                                    Just (TaskNode task)

                                            a ->
                                                Just a
                                    )
                                    fs.nodes
                        }
            in
            deleteTasks_ rest newFS


deleteTaskEdges : Id Task -> FileSystem -> FileSystem
deleteTaskEdges taskId (FileSystem fs) =
    FileSystem
        { fs
            | edges =
                List.filter
                    (\x ->
                        case x of
                            ParentOfTask _ tid ->
                                tid /= taskId

                            _ ->
                                True
                    )
                    fs.edges
        }


deleteFolderEdges : Id Folder -> FileSystem -> FileSystem
deleteFolderEdges folderId (FileSystem fs) =
    FileSystem
        { fs
            | edges =
                List.filter
                    (\x ->
                        case x of
                            ParentOfTask fid _ ->
                                fid /= folderId

                            ParentOfFolder fid1 fid2 ->
                                not (fid1 == folderId || fid2 == folderId)
                    )
                    fs.edges
        }


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
                                            FolderNode folder ->
                                                if Folder.id folder == x then
                                                    Nothing

                                                else
                                                    Just (FolderNode folder)

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
