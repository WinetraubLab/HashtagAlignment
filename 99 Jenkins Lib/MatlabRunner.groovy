//This file contains a single function to run a matlab script for Jenkins

//This function will run a script written in the mfile specified by scriptPath.
//Usually, write a script called runme.m and execute RunMatlabScript("runme.m")
def RunMatlabScript (scriptPath) 
{
	def MATLAB_PATH = "C:\\Program Files\\MATLAB\\R2019a\\bin\\matlab.exe"
	
	//Build M File
	//////////////
			
	// copy the m file to Testers
	bat("@copy /Y '" + scriptPath + "' Testers\\hiddenRunme.m > nooutput") 
			
	// Type matlab file to output log
	bat("""
		@echo off
		echo """ + scriptPath + """
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
		
		bat("""cd Testers && '""" + MATLAB_PATH + """' -nosplash -nodesktop -wait -r "runme_Jenkins('hiddenRunme')" -logfile matlablog.txt""")
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