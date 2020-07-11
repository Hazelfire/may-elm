import {connect} from 'react-redux'
import { select, setFolder } from '../actions'
import {getSelected, calculateListUrgency, calculateTodoOrder, calculateListVelocity, calculateListBait} from '../selectors'
import Statistics from '../components/Statistics'

const mapStateToProps = (state, ownProps) => {
  return {
    urgency: calculateListUrgency(state).toFixed(2),
    bait: calculateListBait(state).toFixed(2),
    velocity: calculateListVelocity(state).toFixed(2),
    todo: calculateTodoOrder(state),
    selected: getSelected(state),
  }
};

const mapDispatchToProps = (dispatch) => {
  return {
    onSelectTask: (task) => {
      dispatch(setFolder(task.parent));
      dispatch(select(task.id));
    }
  }
};

export default connect(mapStateToProps, mapDispatchToProps)(Statistics)
