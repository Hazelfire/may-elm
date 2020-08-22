module May.Task exposing
    ( Task
    , decode
    , doneOn
    , due
    , duration
    , encode
    , id
    , name
    , new
    , rename
    , setDoneOn
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
    , due : Maybe Time.Posix
    , doneOn : Maybe Time.Posix
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
        , due = Nothing
        , doneOn = Nothing
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


doneOn : Task -> Maybe Time.Posix
doneOn (Task task) =
    task.doneOn


setDue : Maybe Time.Posix -> Task -> Task
setDue newDue (Task task) =
    Task <| { task | due = newDue }


setDoneOn : Maybe Time.Posix -> Task -> Task
setDoneOn newDoneOn (Task task) =
    Task <| { task | doneOn = newDoneOn }


catJusts : List (Maybe a) -> List a
catJusts lst =
    case lst of
        [] ->
            []

        (Just a) :: xs ->
            a :: catJusts xs

        Nothing :: xs ->
            catJusts xs


encode : Task -> E.Value
encode task =
    let
        fields =
            [ ( "name", E.string (name task) )
            , ( "duration", E.float (duration task) )
            , ( "id", Id.encode (id task) )
            ]

        optionals =
            catJusts
                [ Maybe.map (\d -> ( "due", E.int (Time.posixToMillis d) )) (due task)
                , Maybe.map (\d -> ( "doneOn", E.int (Time.posixToMillis d) )) (doneOn task)
                ]
    in
    E.object (optionals ++ fields)


decode : D.Decoder Task
decode =
    D.map Task <|
        D.map5 TaskInternals
            (D.field "id" Id.decode)
            (D.field "name" D.string)
            (D.field "duration" D.float)
            (D.maybe (D.field "due" (D.map Time.millisToPosix D.int)))
            (D.maybe (D.field "doneOn" (D.map Time.millisToPosix D.int)))
