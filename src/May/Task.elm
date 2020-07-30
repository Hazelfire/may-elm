module May.Task exposing
    ( Task
    , decode
    , due
    , duration
    , encode
    , id
    , name
    , new
    , rename
    , setDue
    , setDuration
    )

import Json.Decode as D
import Json.Encode as E
import May.Id as Id exposing (Id)
import Time


type Task
    = Task TaskInternals


type alias TaskInternals =
    { id : Id Task
    , name : String
    , duration : Float
    , dependencies : List (Id Task)
    , due : Maybe Time.Posix
    , labels : List String
    }


id : Task -> Id Task
id (Task task) =
    task.id


new : Id Task -> String -> Task
new taskId newName =
    Task
        { id = taskId
        , name = newName
        , duration = 0.0
        , labels = []
        , dependencies = []
        , due = Nothing
        }


duration : Task -> Float
duration (Task task) =
    task.duration


name : Task -> String
name (Task task) =
    task.name


rename : String -> Task -> Task
rename newName (Task task) =
    Task { task | name = newName }


setDuration : Float -> Task -> Task
setDuration newDuration (Task task) =
    Task <| { task | duration = newDuration }


due : Task -> Maybe Time.Posix
due (Task task) =
    task.due


setDue : Maybe Time.Posix -> Task -> Task
setDue newDue (Task task) =
    Task <| { task | due = newDue }


encode : Task -> E.Value
encode task =
    let
        fields =
            [ ( "name", E.string (name task) )
            , ( "duration", E.float (duration task) )
            , ( "id", Id.encode (id task) )
            ]
    in
    case due task of
        Just dueDate ->
            E.object (( "due", E.int (Time.posixToMillis dueDate) ) :: fields)

        Nothing ->
            E.object fields


decode : D.Decoder Task
decode =
    D.map Task <|
        D.map6 TaskInternals
            (D.field "id" Id.decode)
            (D.field "name" D.string)
            (D.field "duration" D.float)
            (D.succeed [])
            (D.maybe (D.field "due" (D.map Time.millisToPosix D.int)))
            (D.succeed [])
