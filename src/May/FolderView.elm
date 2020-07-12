module May.FolderView exposing
    ( FolderView
    , closeConfirmDelete
    , confirmDelete
    , currentFolder
    , editFolderName
    , finishEditFolderName
    , isConfirmDelete
    , isEditingName
    , new
    , workingName
    )

import May.FolderId as FolderId


type FolderView
    = FolderView
        { currentFolder : FolderId.FolderId
        , editState : FolderViewEditState
        }


type FolderViewEditState
    = NotEditing
    | ConfirmDelete
    | EditingName String


new : FolderId.FolderId -> FolderView
new folderId =
    FolderView
        { currentFolder = folderId
        , editState = NotEditing
        }


confirmDelete : FolderView -> FolderView
confirmDelete (FolderView folderViewModal) =
    FolderView { folderViewModal | editState = ConfirmDelete }


closeConfirmDelete : FolderView -> FolderView
closeConfirmDelete (FolderView folderViewModel) =
    FolderView { folderViewModel | editState = NotEditing }


editFolderName : FolderView -> String -> FolderView
editFolderName (FolderView folderViewModel) initial =
    FolderView { folderViewModel | editState = EditingName initial }


finishEditFolderName : FolderView -> FolderView
finishEditFolderName =
    closeConfirmDelete


currentFolder : FolderView -> FolderId.FolderId
currentFolder (FolderView folderViewModel) =
    folderViewModel.currentFolder


isEditingName : FolderView -> Bool
isEditingName (FolderView folderView) =
    case folderView.editState of
        EditingName _ ->
            True

        _ ->
            False


isConfirmDelete : FolderView -> Bool
isConfirmDelete (FolderView folderView) =
    case folderView.editState of
        ConfirmDelete ->
            True

        _ ->
            False


workingName : FolderView -> String
workingName (FolderView folderView) =
    case folderView.editState of
        EditingName name ->
            name

        _ ->
            ""
