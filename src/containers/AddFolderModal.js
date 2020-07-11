import React from 'react';
import FolderModal from '../components/FolderModal';
import { ResourceState } from '../actionset';
import { connect } from 'react-redux';
import { folderset } from '../actions';

const mapStateToProps = (state, myProps) => {
  return {
    title: "Add New Folder",
    trigger: myProps.trigger,
    buttonText: "Add folder",
  }
};

const mapDispatchToProps = (dispatch, ownProps) => {
  return {
    onModalClose: (folder) => {
      let parent = ownProps.folder;
      dispatch(folderset.add({...folder, parent: parent.id}));
    }
  }
};

export default connect(mapStateToProps, mapDispatchToProps)(FolderModal);
