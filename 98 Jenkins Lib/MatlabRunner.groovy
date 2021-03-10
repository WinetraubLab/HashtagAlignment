//This file contains a single function to run a matlab script for Jenkins

//This function will run a script written in the mfile specified by scriptPath.
//Usually, write a script called runme.m and execute RunMatlabScript("runme.m")
def RunMatlabScript (scriptPath, isConnectToCluster=false) 
{
	def matlab_2019a = new File('C:\\Program Files\\MATLAB\\R2019a\\bin\\matlab.exe')
	def matlab_2019b = new File('C:\\Program Files\\MATLAB\\R2019b\\bin\\matlab.exe')
	def matlab_2020b = new File('C:\\Program Files\\MATLAB\\R2020b\\bin\\matlab.exe')
	
	def MATLAB_PATH = "Unknown"
	if (matlab_2020b.exists())
	{
		MATLAB_PATH = '"C:\\Program Files\\MATLAB\\R2020b\\bin\\matlab.exe"'
	}
	else if (matlab_2019a.exists())
	{
		MATLAB_PATH = '"C:\\Program Files\\MATLAB\\R2019a\\bin\\matlab.exe"'
	}
	else if (matlab_2019b.exists())
	{
		MATLAB_PATH = '"C:\\Program Files\\MATLAB\\R2019b\\bin\\matlab.exe"'
	}
	else
	{
		throw("Could not find any of the matlab versions suported")
	}
	
	//Build M File
	//////////////
			
	// copy the m file to Testers
	bat('@copy /Y "' + scriptPath + '" Testers\\hiddenRunme.m > nooutput') 
			
	// Type matlab file to output log
	bat("""
		@echo off
		echo """ + scriptPath + """ / Testers\\hiddenRunme.m 
		echo ---------------
		type Testers\\hiddenRunme.m """) 
		
		
	//Run Matlab
	////////////
	
	try
	{
		//Usefull links
		echo "- Running Matlab log can be found here:\n\t" + env.BUILD_URL + "execution/node/3/ws/Testers/matlablog.txt/*view*/" + "\n" +
			 "- Runme file:\n\t" + env.BUILD_URL + "execution/node/3/ws/Testers/hiddenRunme.m/*view*/" + "\n" +
			 "- Workspace:\n\t" + env.BUILD_URL + "execution/node/3/ws/"
		
		try
		{
			def statusBeforeRunningMatlab = currentBuild.result
			bat("""cd Testers && """ + MATLAB_PATH + """ -nosplash -nodesktop -wait -r "runme_Jenkins('hiddenRunme',""" + isConnectToCluster + """)" -logfile matlablog.txt""")
		}
		catch (Exception e)
		{
			echo"here 1"
			if (statusBeforeRunningMatlab == "SUCCESS") // Only if status use to be success
			{
				echo "here2"
				// Go over output of matlab, see if it tried to use exit code 0, if that is the case ignore error
				def matlabLog = new File('Testers\\matlablog.txt');
				def matlabLogText = matlabLog.getText("UTF-8");
				echo("->" + statusBeforeRunningMatlab)
				if (matlabLogText.endsWith("Exit Code: 0\n"))
				{
					currentBuild.result = 'SUCCESS' // Override status
				}
			}
		}
	}
	catch(Exception e)
	{
		throw("Matlab Failed")
	}
	finally
	{
		//Delete hiddenRunme.m
		bat("@del /f  Testers\\hiddenRunme.m");
		
		//In any case, copy what we did to log folder
		bat """
			@echo off
			echo ---------------------------- MATLAB LOG ----------------------------
			echo --------------------------------------------------------------------
			type Testers\\matlablog.txt
			echo ------------------------------ LOG END -----------------------------
			echo --------------------------------------------------------------------
			"""
	}
}

return this;