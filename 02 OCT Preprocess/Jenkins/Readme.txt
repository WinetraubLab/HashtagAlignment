This file contains the jenkins job configuration, so that everytime jenkins starts it will automatically pull the job from the repository and run it.

To set it up, open Jenkins, add pipeline job.
Under defenition, select pipeline script from SCM.
Point to this Jenkinsfile

Jenkinsfile is readable with text editor.

Jenkinsfile_Auto   - suited for running after 01 OCT Scan and Pattern\Jenkinsfile in the same computer is two parts of the same process
Jenkinsfile_Single - is designed to preform a single run on a single file.