include "_svn_api_ver.pxi"
from apr_1.apr cimport apr_size_t
from apr_1.apr_pools cimport apr_pool_t
from subversion_1.svn_types cimport *
from subversion_1.svn_string cimport svn_string_t

cdef extern from "svn_delta.h" nogil:
    ctypedef enum svn_delta_action:
        svn_txdelta_source
        svn_txdelta_target
        svn_txdelta_new
    ctypedef struct svn_txdelta_op_t:
        svn_delta_action action_code
        apr_size_t offset
        apr_size_t length
    ctypedef struct svn_txdelta_window_t:
        svn_filesize_t sview_offset
        apr_size_t sview_len
        apr_size_t tview_len
        int num_ops
        int src_ops
        const svn_txdelta_op_t * ops
        const svn_string_t * new_data
    ctypedef svn_error_t * (* svn_txdelta_window_handler_t)(
                svn_txdelta_window_t * window, void * baton)
    ctypedef struct svn_txdelta_stream_t:
        pass
    IF SVN_API_VER >= (1, 10):
        ctypedef svn_error_t * (* svn_txdelta_stream_open_func_t)(
                    svn_txdelta_stream_t ** txdelta_stream, void * baton,
                    apr_pool_t * result_pool, apr_pool_t * scratch_pool)

ctypedef svn_error_t * (* set_target_revision_func_t)(
            void * edit_baton, svn_revnum_t target_revision,
            apr_pool_t * scratch_pool)
ctypedef svn_error_t * (* open_root_func_t)(
            void * edit_baton, svn_revnum_t base_revision,
            apr_pool_t *result_pool, void ** root_baton)
ctypedef svn_error_t * (* delete_entry_func_t)(
            const char * path, svn_revnum_t revision, void * parent_banton,
            apr_pool_t * scratch_pool)
ctypedef svn_error_t * (* add_directory_func_t)(
            const char * path, void * parent_baton, const char * copyfrom_path,
            svn_revnum_t copyfrom_revision, apr_pool_t * result_pool,
            void ** child_baton)
ctypedef svn_error_t * (* open_directory_func_t)(
            const char * path, void * parent_baton, svn_revnum_t base_revision,
            apr_pool_t * result_pool, void ** child_baton)
ctypedef svn_error_t * (* change_dir_prop_func_t)(
            void * dir_baton, const char * name, const svn_string_t * value,
            apr_pool_t * scratch_pool)
ctypedef svn_error_t * (* close_directory_func_t)(
            void * dir_baton, apr_pool_t * scratch_pool)
ctypedef svn_error_t * (* absent_directory_func_t)(
            const char * path, void * parent_baton, apr_pool_t * scratch_pool)
ctypedef svn_error_t * (* add_file_func_t)(
            const char * path, void * parent_baton,
            const char * copyfrom_path, svn_revnum_t copyfrom_revision,
            apr_pool_t * result_pool, void ** file_baton)
ctypedef svn_error_t * (* open_file_func_t)(
            const char * path, void * parent_baton, svn_revnum_t base_revision,
            apr_pool_t * result_pool, void ** file_baton)
ctypedef svn_error_t * ( * apply_textdelta_func_t)(
            void * file_baton, const char * base_checksum,
            apr_pool_t * result_pool, svn_txdelta_window_handler_t * handler,
            void ** handler_baton)
ctypedef svn_error_t * ( * change_file_prop_func_t)(
            void * file_baton, const char * name, const svn_string_t * value,
            apr_pool_t * scratch_pool)
ctypedef svn_error_t * ( * close_file_func_t)(
            void * file_baton, const char * text_checksum,
            apr_pool_t * scratch_pool)
ctypedef svn_error_t * ( * absent_file_func_t)(
            const char * path, void * parent_baton, apr_pool_t * scratch_pool)
ctypedef svn_error_t * ( * close_edit_func_t)(
            void * edit_baton, apr_pool_t * scratch_pool)
ctypedef svn_error_t * ( * abort_edit_func_t)(
            void * edit_baton, apr_pool_t * scratch_pool)
IF SVN_API_VER >= (1, 10):
    ctypedef svn_error_t * ( * apply_textdelta_stream_func_t)(
                const svn_delta_editor_t * editor, void * file_baton,
                const char * base_checksum,
                svn_txdelta_stream_open_func_t open_func,
                void * open_baton, apr_pool_t * scratch_pool)

cdef extern from "svn_delta.h" nogil:
    IF SVN_API_VER >= (1, 10):
        ctypedef struct svn_delta_editor_t:
            set_target_revision_func_t set_target_revision
            open_root_func_t open_root
            delete_entry_func_t delete_entry
            add_directory_func_t add_directory
            open_directory_func_t open_directory
            change_dir_prop_func_t change_dir_prop
            close_directory_func_t close_directory
            absent_directory_func_t absent_directory
            add_file_func_t add_file
            open_file_func_t open_file
            apply_textdelta_func_t apply_textdelta
            change_file_prop_func_t change_file_prop
            close_file_func_t close_file
            absent_file_func_t absent_file
            close_edit_func_t close_edit
            abort_edit_func_t abort_edit
            apply_textdelta_stream_func_t apply_textdelta_stream
    ELSE:
        ctypedef struct svn_delta_editor_t:
            set_target_revision_func_t set_target_revision
            open_root_func_t open_root
            delete_entry_func_t delete_entry
            add_directory_func_t add_directory
            open_directory_func_t open_directory
            change_dir_prop_func_t change_dir_prop
            close_directory_func_t close_directory
            absent_directory_func_t absent_directory
            add_file_func_t add_file
            open_file_func_t open_file
            apply_textdelta_func_t apply_textdelta
            change_file_prop_func_t change_file_prop
            close_file_func_t close_file
            absent_file_func_t absent_file
            close_edit_func_t close_edit
            abort_edit_func_t abort_edit
    svn_delta_editor_t * svn_delta_default_editor(apr_pool_t * pool)
