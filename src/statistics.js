import moment from 'moment';

function removeDuplicateTasks(tasks) {
  return tasks.filter(
    (task, index) =>
      !tasks.find(
        (searchTask, searchIndex) =>
          searchIndex > index && task.id === searchTask.id
      )
  );
}

function getWithIds(allTasks, taskIds) {
  return allTasks.filter(task => taskIds.includes(task.id));
}

function taskChildren(task, allTasks) {
  if (task.dependencies) {
    let children = getWithIds(allTasks, task.dependencies);
    return removeDuplicateTasks(
      children.flatMap(task => taskChildren(task, allTasks))
    ).concat([task]);
  } else {
    return [task];
  }
}


function getDueDateMapping(tasks) {
  let dueDateMap = new Map();

  let heads = tasks.filter(task => task.due);
  let childrenPairs = heads.map(task => [task.due, taskChildren(task, tasks)]);

  for (let childPair of childrenPairs) {
    let dueDate = childPair[0];
    let children = childPair[1];

    for (let child of children) {
      let currentDueDate = dueDateMap.get(child.id);
      if (currentDueDate) {
        if (currentDueDate > dueDate) {
          dueDateMap.set(child.id, dueDate);
        }
      } else {
        dueDateMap.set(child.id, dueDate);
      }
    }
  }
  return dueDateMap;
}

function taskVelocity(task, time, due) {
  if (!task.done && (due || task.due)) {
    let days = moment
      .duration(moment(due ? due : task.due).diff(moment.unix(time)))
      .asDays();
    if (days > 0) {
      return task.duration / days / days;
    } else {
      return Infinity;
    }
  } else {
    return 0;
  }
}
function taskUrgency(task, time, due) {
  if (!task.done && (due || task.due)) {
    let days = moment
      .duration(moment(due ? due : task.due).diff(moment.unix(time)))
      .asDays();
    if (days > 0) {
      return task.duration / days;
    } else {
      return Infinity;
    }
  } else {
    return 0;
  }
}

export function listUrgency(tasks){
  let time = moment().unix();
  let tasksNotDone = tasks.filter(task => !task.done);
  let dueDateMap = getDueDateMapping(tasks);

  return tasksNotDone.reduce(
    (sum, task) => sum + taskUrgency(task, time, dueDateMap.get(task.id)),
    0
  );
}

export function listVelocity(tasks){
  let time = moment().unix();
  let tasksNotDone = tasks.filter(task => !task.done);
  let dueDateMap = getDueDateMapping(tasks);

  return tasksNotDone.reduce(
    (sum, task) => sum + taskVelocity(task, time, dueDateMap.get(task.id)),
    0
  );
}

function getAncestorRelationships(tasks) {
  let relationships = [];
  for (let task of tasks) {
    let newRelationships = task.dependencies.map(dependency => [
      dependency,
      task.id,
    ]);
    relationships = relationships.concat(newRelationships);
  }
  return new Map(relationships);
}

function taskChainedUrgency(task, time, allTasks, due, ancestors) {
  let urgency = taskUrgency(task, time, due);
  let currentTask = task;
  let ancestorId;
  while ((ancestorId = ancestors.get(currentTask.id))) {
    currentTask = getTaskById(allTasks, ancestorId);
    urgency += taskUrgency(currentTask, time, due);
  }
  return urgency;
}

function urgencyForEach(tasks){
  let time = moment().unix();
  let dueDateMap = getDueDateMapping(tasks);
  let ancestors = getAncestorRelationships(tasks);

  return tasks.map(task => {
    let urgency;
    let impliedDue = dueDateMap.get(task.id);
    if (task.done) urgency = 0;
    else
      urgency = taskChainedUrgency(task, time, tasks, impliedDue, ancestors);
    return { ...task, urgency: urgency, impliedDue };
  });
}

export function listBait(tasks){
  tasks = urgencyForEach(tasks);
  let tasksWithUrgency = tasks.filter(
    task => !task.done && (task.urgency > 0 || task.due)
  );
  let sortedTasks = tasksWithUrgency.sort((a, b) => b.urgency - a.urgency);
  let tasksWithoutFirst = sortedTasks.filter((_, index) => index > 0);
  return tasksWithoutFirst.reduce((sum, task) => sum + task.urgency, 0);
}

export function todoOrder(tasks){
  return urgencyForEach(tasks)
      .filter(task => !task.done && (task.urgency > 0 || task.due))
      .sort((a, b) => b.urgency - a.urgency)
}

