
export class TaskSerialiser {
  toInternal(task){
    let duration = 0;
    let segments = task.duration.split(":");
    for(let i = segments.length - 1; i >= 0; i--){
      duration += parseInt(segments[i]) * Math.pow(60, segments.length - i - 1);
    }
    return {
      ...task,
      duration: duration / 60 / 60
    }
  }

  toNetwork(task){
    let newTask = {
      ...task
    };
    if(newTask.duration){
      newTask.duration *= 60 * 60; 
    }
    return newTask;
  }
}

export class NullSerialiser {
  toInternal(task){
    return task;
  }

  toNetwork(task){
    return task;
  }
}
