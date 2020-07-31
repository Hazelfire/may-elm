module May.Statistics exposing (bait, labelTasks, taskUrgency, todo, urgency, velocity)

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

                timeInDays =
                    max (toFloat (miliDue - miliNow) / 1000 / 60 / 60 / 24) 1
            in
            if miliDue > miliNow then
                Task.duration task / timeInDays

            else
                0.0

        Nothing ->
            0.0


{-| Calculates how many hours per day of work you need to do to get everything
done by their due dates
-}
urgency : Time.Posix -> List Task -> Float
urgency now tasks =
    let
        taskLabels =
            labelTasks now tasks

        doTodayTime =
            List.sum (List.map Task.duration (taskLabels.overdue ++ taskLabels.doToday))

        doSoonTime =
            List.sum (List.map Tuple.second taskLabels.doSoon)
    in
    doSoonTime + doTodayTime


type alias LabeledTasks =
    { overdue : List Task
    , doToday : List Task
    , doSoon : List ( Task, Float )
    , doLater : List Task
    }


labelTasks : Time.Posix -> List Task -> LabeledTasks
labelTasks now tasks =
    let
        sortedTasks =
            List.sortBy (\x -> Maybe.withDefault 0 (Maybe.map Time.posixToMillis (Task.due x))) tasks
    in
    labelTasks_ now now 0 0 sortedTasks


labelTasks_ : Time.Posix -> Time.Posix -> Float -> Float -> List Task -> LabeledTasks
labelTasks_ now last_due residual currentUrgency tasks =
    case tasks of
        task :: rest ->
            case Task.due task of
                Just dueDate ->
                    let
                        timeUntilDueInDays =
                            toFloat (Time.posixToMillis dueDate - Time.posixToMillis now) / 1000 / 60 / 60 / 24

                        timeUntilDueInDaysCapped =
                            max timeUntilDueInDays 1
                    in
                    if timeUntilDueInDays <= 0.0 then
                        let
                            newUrgency =
                                Task.duration task + currentUrgency

                            otherLabels =
                                labelTasks_ now now 0 newUrgency rest
                        in
                        { otherLabels | overdue = task :: otherLabels.overdue }

                    else if timeUntilDueInDays <= 1.0 then
                        let
                            newUrgency =
                                Task.duration task + currentUrgency

                            otherLabels =
                                labelTasks_ now dueDate 0 newUrgency rest
                        in
                        { otherLabels | doToday = task :: otherLabels.doToday }

                    else
                        let
                            addedResidual =
                                toFloat (Time.posixToMillis dueDate - Time.posixToMillis last_due) / 1000 / 60 / 60 / 24 * currentUrgency + residual
                        in
                        if addedResidual >= Task.duration task then
                            let
                                newResidual =
                                    addedResidual - Task.duration task

                                otherLabels =
                                    labelTasks_ now dueDate newResidual currentUrgency rest
                            in
                            { otherLabels | doLater = task :: otherLabels.doLater }

                        else
                            let
                                restOfTaskDuration =
                                    Task.duration task - addedResidual

                                newUrgency =
                                    currentUrgency + restOfTaskDuration / timeUntilDueInDaysCapped

                                otherLabels =
                                    labelTasks_ now dueDate 0 newUrgency rest
                            in
                            { otherLabels | doSoon = ( task, restOfTaskDuration / timeUntilDueInDaysCapped ) :: otherLabels.doSoon }

                Nothing ->
                    let
                        otherLabels =
                            labelTasks_ now last_due residual currentUrgency rest
                    in
                    { otherLabels | doLater = task :: otherLabels.doLater }

        [] ->
            { doLater = []
            , doToday = []
            , doSoon = []
            , overdue = []
            }



{- Calculates the urgency of a sublist. The second argument and second tuple
   is the residual. Assumes all tasks are in order of due date
-}


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
