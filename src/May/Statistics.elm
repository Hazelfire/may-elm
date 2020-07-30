module May.Statistics exposing (bait, taskUrgency, todo, urgency, velocity)

import May.Task as Task exposing (Task)
import Time


taskUrgency : Time.Posix -> Task -> Float
taskUrgency now task =
    case Task.due task of
        Just dueDate ->
            let
                miliDue =
                    Time.posixToMillis dueDate

                miliNow =
                    Time.posixToMillis now
            in
            if miliDue > miliNow then
                Task.duration task * 60 * 60 * 1000 / toFloat (miliDue - miliNow) * 24

            else
                0.0

        Nothing ->
            0.0


urgency : Time.Posix -> List Task -> Float
urgency now tasks =
    List.sum (List.map (taskUrgency now) tasks)


taskVelocity : Time.Posix -> Task -> Float
taskVelocity now task =
    case Task.due task of
        Just dueDate ->
            let
                miliDue =
                    Time.posixToMillis dueDate

                miliNow =
                    Time.posixToMillis now

                timeInDays =
                    toFloat (miliDue - miliNow) / 60 / 60 / 1000 / 24
            in
            if miliDue > miliNow then
                Task.duration task / timeInDays / timeInDays

            else
                0.0

        Nothing ->
            0.0


velocity : Time.Posix -> List Task -> Float
velocity now tasks =
    List.sum (List.map (taskVelocity now) tasks)


todo : Time.Posix -> List Task -> List Task
todo now tasks =
    List.sortBy (taskUrgency now >> (*) -1) tasks


bait : Time.Posix -> List Task -> Float
bait now tasks =
    let
        nextTodo =
            List.head <| todo now tasks
    in
    case nextTodo of
        Just topTask ->
            urgency now tasks - taskUrgency now topTask

        Nothing ->
            0.0
