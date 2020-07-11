import React from 'react';
import FolderSelector from '../components/FolderSelector';
import { ResourceState } from '../actionset';
import { connect } from 'react-redux';
import { setFolder, folderset } from '../actions';

const mapStateToProps = (state, myProps) => {
  return {
    folders: new ResourceState(state.serverReducer.folders).toList()
  };
};

const mapDispatchToProps = (dispatch, ownProps) => {
  return ownProps;
};

export default connect(mapStateToProps, mapDispatchToProps)(FolderSelector);
