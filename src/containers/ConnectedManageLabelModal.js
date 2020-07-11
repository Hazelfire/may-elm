import React from 'react';
import ManageLabelModal from '../components/ManageLabelModal';
import { ResourceState } from '../actionset';
import { connect } from 'react-redux';
import { labelset } from '../actions';

const mapStateToProps = (state, myProps) => {
  return {
    labels: new ResourceState(state.serverReducer.labels).toList(),
  };
};

const mapDispatchToProps = (dispatch, ownProps) => {
  return {
    deleteLabelWithId: (id) => {
      dispatch(labelset.delete(id));
    },
    editLabelWithId: (id, changes) => {
      dispatch(labelset.edit(id, changes));
    },
  };
};

export default connect(mapStateToProps, mapDispatchToProps)(ManageLabelModal);
