module May.SyncList exposing
    ( SyncAction(..)
    , SyncList
    , SyncNodeId(..)
    , SyncUpdateNode(..)
    , addNode
    , decode
    , deleteNode
    , empty
    , encode
    , needsSync
    )

{-| The SyncList keeps track of all the changes that have been made that have
not yet been sent to the server.
-}

import Json.Decode as D
import Json.Encode as E
import May.Folder as Folder exposing (Folder)
import May.Id as Id exposing (Id)
import May.Task as Task exposing (Task)
import Time


{-| Note that SyncUpdateFolder always has a parent node (Id Folder).
This is because the root folder is not stored in the server
-}
type SyncUpdateNode
    = SyncUpdateFolder (Id Folder) Folder
    | SyncUpdateTask (Id Folder) Task


type SyncNodeId
    = SyncFolderId (Id Folder)
    | SyncTaskId (Id Task)


{-| Represents an action that can be completed on the backend
-}
type SyncAction
    = SyncUpdate SyncUpdateNode
    | SyncDelete SyncNodeId


type alias SyncList =
    List SyncAction


empty : SyncList
empty =
    []


{-| Encodes the sync list. This encodes the list in the format that is accepted
by the server. The same encoder is used for storing the synclist in localstorage
-}
encode : SyncList -> E.Value
encode list =
    E.list encodeSyncAction list


encodeSyncAction : SyncAction -> E.Value
encodeSyncAction action =
    case action of
        SyncUpdate update ->
            E.object [ ( "action", E.string "update" ), ( "payload", encodeSyncUpdateNode update ) ]

        SyncDelete nodeId ->
            E.object [ ( "action", E.string "delete" ), ( "id", encodeSyncNodeId nodeId ) ]


encodeSyncUpdateNode : SyncUpdateNode -> E.Value
encodeSyncUpdateNode updateNode =
    case updateNode of
        SyncUpdateFolder pid folder ->
            E.object
                [ ( "type", E.string "folder" )
                , ( "id", Id.encode (Folder.id folder) )
                , ( "name", E.string (Folder.name folder) )
                , ( "pid", Id.encode pid )
                ]

        SyncUpdateTask pid task ->
            let
                fields =
                    [ ( "type", E.string "task" )
                    , ( "id", Id.encode (Task.id task) )
                    , ( "name", E.string (Task.name task) )
                    , ( "duration", E.float (Task.duration task) )
                    , ( "pid", Id.encode pid )
                    ]
            in
            case Task.due task of
                Just dueDate ->
                    E.object (( "due", E.int (Time.posixToMillis dueDate) ) :: fields)

                Nothing ->
                    E.object fields


encodeSyncNodeId : SyncNodeId -> E.Value
encodeSyncNodeId node =
    case node of
        SyncTaskId tid ->
            Id.encode tid

        SyncFolderId fid ->
            Id.encode fid


decode : D.Decoder SyncList
decode =
    D.succeed empty


needsSync : SyncList -> Bool
needsSync x =
    List.length x > 0


syncUpdateNodeId : SyncUpdateNode -> SyncNodeId
syncUpdateNodeId node =
    case node of
        SyncUpdateTask _ task ->
            SyncTaskId (Task.id task)

        SyncUpdateFolder _ folder ->
            SyncFolderId (Folder.id folder)


syncActionId : SyncAction -> SyncNodeId
syncActionId action =
    case action of
        SyncDelete id ->
            id

        SyncUpdate node ->
            syncUpdateNodeId node


filterOutId : SyncNodeId -> SyncList -> SyncList
filterOutId id list =
    List.filter (syncActionId >> (/=) id) list


addNode : SyncUpdateNode -> SyncList -> SyncList
addNode update list =
    SyncUpdate update :: filterOutId (syncUpdateNodeId update) list


deleteNode : SyncNodeId -> SyncList -> SyncList
deleteNode id sl =
    SyncDelete id :: filterOutId id sl
