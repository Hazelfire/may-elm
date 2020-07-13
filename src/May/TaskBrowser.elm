module May.TaskBrowser exposing
    ( ItemId(..)
    , TaskBrowser
    , closeConfirmDelete
    , confirmDelete
    , currentView
    , editName
    , finishEditName
    , isConfirmDelete
    , isEditingName
    , new
    , workingName
    )

import May.FolderId as FolderId
import May.TaskId as TaskId


type TaskBrowser
    = TaskBrowser
        { currentView : ItemId
        , editState : TaskBrowserEditState
        }


type ItemId
    = ItemIdFolder FolderId.FolderId
    | ItemIdTask TaskId.TaskId


type TaskBrowserEditState
    = NotEditing
    | ConfirmDelete
    | EditingName String


new : ItemId -> TaskBrowser
new itemId =
    TaskBrowser
        { currentView = itemId
        , editState = NotEditing
        }


confirmDelete : TaskBrowser -> TaskBrowser
confirmDelete (TaskBrowser folderViewModal) =
    TaskBrowser { folderViewModal | editState = ConfirmDelete }


closeConfirmDelete : TaskBrowser -> TaskBrowser
closeConfirmDelete (TaskBrowser folderViewModel) =
    TaskBrowser { folderViewModel | editState = NotEditing }


editName : TaskBrowser -> String -> TaskBrowser
editName (TaskBrowser folderViewModel) initial =
    TaskBrowser { folderViewModel | editState = EditingName initial }


finishEditName : TaskBrowser -> TaskBrowser
finishEditName =
    closeConfirmDelete


currentView : TaskBrowser -> ItemId
currentView (TaskBrowser taskBrowser) =
    taskBrowser.currentView


isEditingName : TaskBrowser -> Bool
isEditingName (TaskBrowser folderView) =
    case folderView.editState of
        EditingName _ ->
            True

        _ ->
            False


isConfirmDelete : TaskBrowser -> Bool
isConfirmDelete (TaskBrowser folderView) =
    case folderView.editState of
        ConfirmDelete ->
            True

        _ ->
            False


workingName : TaskBrowser -> String
workingName (TaskBrowser folderView) =
    case folderView.editState of
        EditingName name ->
            name

        _ ->
            ""
