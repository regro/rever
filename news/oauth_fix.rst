**Added:**

* added get_oauth_token in github.xsh to authorize rever application to make changes to a user's github
* added GitHub_raise_for_status helper function for get_oauth_token in github.xsh

**Changed:**

* changed write_credfile in github.xsh to now call get_oauth_token. User is no longer prompted for password as this is handled through a browser
* changed read_credfile in github.xsh to handle new format of credfile (without password)
* changed login in github.xsh to login with OAuth token only
* changed github3 in github.xsh to conform with latest version of github3.py API
* changed test_github.py to handle new behavior of credfile

**Deprecated:**


**Removed:**


**Fixed:**

* Fixed broken GitHub login behavior by using OAuth authentication

**Security:**

