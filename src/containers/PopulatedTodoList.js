// @flow
import { connect } from 'react-redux';
import { setFolder, taskset} from '../actions';
import { ResourceState } from '../actionset';
import { getTasksInSelectedFolder, getFoldersInSelectedFolder, getSelectedFolder} from '../selectors';
import TodoList from '../components/TodoList';

function expandIds(tasks, allTasks, allLabels) {
  return tasks.map(task => ({
    ...task,
    dependencies: expandDependencies(task.dependencies, allTasks),
    labels: expandLabels(task.labels, allLabels),
  }));
}

function expandLabels(labels, allLabels) {
  return labels.map(label =>
    allLabels.find((checkLabel) => checkLabel.id == label)
  );
}

function expandDependencies(dependencies, allTasks){
  return dependencies.map(dependency =>
    allTasks.find((checkTask) => checkTask.id == dependency)
  );
}

const mapStateToProps = (state) => {
  let taskState = new ResourceState(state.serverReducer.tasks);
  let labelState = new ResourceState(state.serverReducer.labels);

  let folderState = new ResourceState(state.serverReducer.folders);
  let folder = getSelectedFolder(state);

  return {
    loading: taskState.getListStatus().loading || folderState.getListStatus().loading,
    error: taskState.getListStatus().error,
    name: folder ? folder.name: '',
    tasks: expandIds(getTasksInSelectedFolder(state).map((task) => ({...task, status: taskState.getObjectStatus(task.id)})), taskState.toList(), labelState.toList()),
    folders: getFoldersInSelectedFolder(state).map((folder) => ({...folder, status: folderState.getObjectStatus(folder.id)})),
    folder: folder,
  };

};

const mapDispatchToProps = (dispatch) => {
  return {
    backFolder: (parent) => dispatch(setFolder(parent)),
    onDoneStateChanged: (item) => dispatch(taskset.edit(item.id, {done: !item.done})),
    onDelete: (item) => dispatch(taskset.delete(item.id)),
    onEdit: (id, patches) => dispatch(taskset.edit(id, patches))
  };
};

export default connect(mapStateToProps, mapDispatchToProps)(TodoList);
