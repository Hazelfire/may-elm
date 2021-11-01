# May

This is the frontend of May, a task management application I built to help myself
allocate tasks. May is hosted [here](https://may.hazelfire.net/).

In May, you input a collection of tasks, where each task has a duration and a
due date. From this, May is able to calculate:

- Urgency, The minimum amount of hours per day you need to work in order to get
  all your work done by their due dates
- "Tomorrow", What your urgency will be tomorrow if you were to do no more tasks
  for the rest of the day (basically, cost of procrastination)
- Todo List, The optimal order you should go about completing your tasks, including
  the optimal tasks to complete today, which tasks you should leave until later,
  etc.

The algorithm that calculates these measures is quite complicated and has gone
through several revisions. But in essence it divides the amount of time the tasks
take by the amount of time you have left to complete the task. Therefore creating
an "hours per day" of work done needed. The actual algorithm is however a bit more
complicated than that.

The application is a PWA, runs entirely offline, and can store your tasks between
sessions. It links up to a [haskell backend](https://github.com/Hazelfire/may-haskell)
which allows you to store tasks online instead if sign up.

More information is on the "Help" tab on the [may website](https://may.hazelfire.net/)

## Why May?

I call this project May as it belongs to a series of applications I built in a month.
This particular one started in May, and was originally a command line application
in Ruby, then Python, then [Haskell](https://github.com/Hazelfire/may-haskell).
