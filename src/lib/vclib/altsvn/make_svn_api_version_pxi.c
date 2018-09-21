# include <stdio.h>
# if defined(NEED_SUBVERSION_1_DIR)
# include <subversion-1/svn_version.h>
# else
# include <svn_version.h>
# endif

int
main(void) {
    FILE * fp;
    if (NULL == (fp = fopen("_svn_api_ver.pxi", "w"))) {
        fprintf(stderr, "fail to write open : svn_api_ver.pxi\n");
        exit(1);
    }
    fprintf(fp, "DEF SVN_API_VER = (%ld, %ld)\n",
            (long)SVN_VER_MAJOR, (long)SVN_VER_MINOR);
#if defined(WIN32) || defined(__CYGWIN__) || defined(__OS2__)
    fprintf(fp, "DEF SVN_USE_DOS_PATHS = 1\n");
#else
    fprintf(fp, "DEF SVN_USE_DOS_PATHS = 0\n");
#endif
    fclose(fp);
    exit(0);
}
