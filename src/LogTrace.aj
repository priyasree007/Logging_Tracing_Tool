import java.lang.reflect.*;
import java.io.*;
import java.util.*;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.awt.*;
import java.awt.image.BufferedImage;
import javax.swing.*;
import javax.imageio.ImageIO;
import com.anylogic.engine.Agent;
import com.anylogic.engine.*;
import com.anylogic.engine.presentation.*;


public aspect LogTrace
{

	int counterSetName = 0;
	boolean randomSeedWritten = false;
	boolean experimentStart = false;
	boolean experimentStop = false;
	boolean enableTool = true;
	
	Date startDate = new Date();
	Date endDate;
	DateFormat dateFormat = new SimpleDateFormat("yyyy'.'MM'.'dd'_'hh'.'mm'.'ss'_'a'_'zzz");
	String path = System.getProperty("user.dir");
	String subDir = (path + "/" + "Run" + dateFormat.format(startDate));
	String logpathName = (subDir + "/LogFile" + dateFormat.format(startDate) + ".txt");
	String tracepathName = (subDir + "/" + "TraceFile" + dateFormat.format(startDate) + ".txt");
	FileWriter Log_fw, Trace_fw;
	BufferedWriter Log_bw, Trace_bw;
	PrintWriter Log_pw, Trace_pw;
	
	Random rNew = new Random();
	int seedNew = rNew.nextInt(100000);
	
	Engine myEngine;
	
	//Pointcuts
	
	pointcut getName(): 
		call(* *.getNameOf(..));
	
	pointcut fixSeed(long seed): 
		call(* *.setSeed(..)) && 
		args(seed); 
	
	pointcut modelNameAndCopy(): 
		execution(* *.setup(..));
	
	pointcut setSeed(com.anylogic.engine.Engine engine): 
		execution(* *.setEngine(..)) && 
		args(engine);
	
	pointcut experimentName(): 
		call(* *.setName(..));
	
	pointcut mainParameters(final Agent self, boolean callOnChangeActions): 
		execution(* *.setupRootParameters(..)) && 
		args(self, callOnChangeActions);
	
	pointcut sendMessageWMode(Agent agt, java.lang.Object msg, int mode): 
		execution(* *.send(..)) && 
		args(msg, mode) && 
		target(agt);
	
	pointcut sendMessage(Agent agt, java.lang.Object msg, Agent dest): 
		execution(* *.send(..)) && 
		args(msg, dest) && 
		target(agt);
	
	pointcut receiveMessage(Agent agt, java.lang.Object msg, Agent sender): 
		execution(* *.onReceive(..)) && 
		args(msg, sender) && 
		target(agt);
	
	pointcut enterAState(Agent agt, short state, boolean destination): 
		execution(* *.enterState(..)) && 
		args(state, destination) && 
		target(agt);
	
	pointcut exitAState(Agent agt, short state, Transition tran, boolean source, Statechart statechart): 
		execution(* *.exitState(..)) && 
		args(state, tran, source, statechart) && 
		target(agt);
	
	pointcut experimentStarted(): 
		execution(* com.anylogic.engine.ExperimentSimulation.run(..));
	
	pointcut experimentCompleted(): 
		execution(* *.onEngineFinished(..));
	
	pointcut getPresentation(): 
		execution(* *.getPresentation(..));
	
	
	before(): modelNameAndCopy()
	{
		if (enableTool)
		{
			/*
			 * Get classPath of the class within which, Anylogic simulation initialized.
			 * Since for every Anylogic model, the call to < ? extend Simulation> will 
			 * only be called once through "public static void main(String[] args)"
			 * this advice shall only be executed once.
			 * 
			 * ClassLoader classLoader -- classLoader of the class whose main method is executed 
			 * String className -- the canonical name of the class whose main method is executed
			 *                     e.g. {modelpackage}.{simulationClassName}		                      
			 * String resourcePath -- the resource path to the class whose main method is executed
			 *                        it uses "/" as file-separator, not compatible with all OS.
			 * String classPath -- file path to the the class whose main method is executed
			 */
			 
			ClassLoader classLoader = thisJoinPoint.getSourceLocation().getWithinType().getClassLoader();
			String className = thisJoinPoint.getSourceLocation().getWithinType().getCanonicalName();
			String resourcePath = classLoader.getResource(className.replace(".",File.separator) + ".class").getPath();
			// ".getResource()" will return path using "/" as file-separator, we have to replace it
			// back to system File.seperator, otherwise the display of file path would be wrong.
			String classPath = resourcePath.replace("/", File.separator);
			
			/* Sanity check -- all our assumption is based on a specific folder named with
			 * "..../Workspace/.."+ [model_name] + "_BUILD", if these folder does not exist,
			 * the rest of our code won't work.
			 */
			if (!classPath.contains("Workspace") || !classPath.contains("_BUILD")) {
				System.err.println("\nERROR: Unexpected File Structure, please update Aspect ZipALP");
				System.exit(1);
			}
			
			/* Get 
			 *  -- since the Folder of AnyLogic-compiled model will guarantee to end with "_BUILD"
			 * we can split here and get the first part of this path
			 * 
			 * String modelName -- Anylogic ALP file name, without suffix ".alp"                     
			 */
			String[] modelPath_comp = classPath.toString().split("_BUILD")[0].split(java.util.regex.Pattern.quote(File.separator));
			String modelName = modelPath_comp[modelPath_comp.length - 1];
			System.out.println("Model Name is : " + modelName);
			
			/* Get current model path 
			 * 
			 * String modelDir -- Anylogic ALP file Directory
			 */
			//String modelDir = System.getProperty("user.dir"); --already taken care of = path
			
			 /*Sanity Check -- double check if the ".alp" file exists, if so, will zip it
			 * to its current folder; otherwise, will print error. 
			 */		
			if (!modelName.isEmpty()) {
				File f = new File(path, modelName + ".alp");
				if (f.exists()) {
					copySingleFile(f, new File(subDir, modelName+ "_copy.alp"));
				} else {
					System.err.println("ERROR: ALP file not found, zipping failed.");
				}	
			} else {
				System.err.println("ERROR: ALP file not found, zipping failed.");
			} 
		}
	}	
	
	//copy the file
	private static void copySingleFile(File file, File dest) 
	{
		InputStream input = null;
		OutputStream output = null;
		try {
			input = new FileInputStream(file);
			output = new FileOutputStream(dest);
			byte[] buffer = new byte[1024];
			int len;
			while ((len = input.read(buffer)) > 0) {
				output.write(buffer, 0, len);
			}
			input.close();
			output.close();
			
			System.out.println("****************** AspectJ ALP Zipper ******************");
			System.out.println(file.getCanonicalPath()+"\nis copied to\n"+dest.getCanonicalPath());
			System.out.println("********************************************************");
		} catch (IOException e) {
			e.printStackTrace(System.out);
		}
	}
	//***********************************************************************************************
	
	//Print the Date, Time when the experiment starts and the Random Seed ***************************
	
	after(long seed): fixSeed(seed)
	{
		try {
			if (seed == 0) {
				ClassLoader classLoader = thisJoinPoint.getSourceLocation().getWithinType().getClassLoader();
				String className = thisJoinPoint.getSourceLocation().getWithinType().getCanonicalName();
				System.out.println("SEED 0 : " + thisJoinPoint);
				System.out.println("CLASS : " + className);
				//User Confirmation Window
				JDialog.setDefaultLookAndFeelDecorated(true);
				int response = JOptionPane.showConfirmDialog(null, "Do you want to use the logging and tracing tool?", "Enable/Disable the logging and tracing tool",
				JOptionPane.YES_NO_OPTION, JOptionPane.QUESTION_MESSAGE);
				if (response == JOptionPane.NO_OPTION) {
					enableTool = false;
					System.out.println("'NO' button clicked, hence logging and tracing tool is NOT enabld");
				} else if (response == JOptionPane.YES_OPTION) {
					System.out.println("'YES' button clicked, hence logging and tracing tool is enabld");
				} else if (response == JOptionPane.CLOSED_OPTION) {
					System.out.println("JOptionPane closed, hence logging and tracing tool is enabld by default");
				}
				
				if (enableTool)
				{
					boolean subFolder = (new File(subDir)).mkdir();
					System.out.println("Directory created in set seed ? "+ seed + subFolder);
					
					Log_fw = new FileWriter(logpathName, true);
					Log_bw = new BufferedWriter(Log_fw);
					Log_pw = new PrintWriter(Log_bw);
					
					Trace_fw = new FileWriter(tracepathName, true);
					Trace_bw = new BufferedWriter(Trace_fw);
					Trace_pw = new PrintWriter(Trace_bw);
					
					Log_pw.println("Date and Time when the experiment starts :  " + startDate);	
					Log_pw.println(" ");
					
					Trace_pw.println("Date and Time when the experiment starts :  " + startDate);
					Trace_pw.println(" ");
				}
			}
			else if ((seed != 0) && (randomSeedWritten == false)) {
				if (enableTool)
				{
					ClassLoader classLoader = thisJoinPoint.getSourceLocation().getWithinType().getClassLoader();
					String className = thisJoinPoint.getSourceLocation().getWithinType().getCanonicalName();
					System.out.println("SEED 0 : " + thisJoinPoint);
					System.out.println("CLASS : " + className);
					
					randomSeedWritten = true;
					System.out.println("Date and Time when the experiment starts :  " + startDate);
					System.out.println("Fixed Seed is used by the model and its value is : " + seed);
					
					Log_pw.println("Fixed Seed is used by the model and its value is : " + seed);
					Log_pw.println(" ");
				}
			}
		}
		catch (Exception e) {
			e.printStackTrace(System.out);
		}
	}	


	after(com.anylogic.engine.Engine engine): setSeed(engine)
	{ 
		if (enableTool)
		{
			if (randomSeedWritten == false) {
				myEngine = engine;
				randomSeedWritten = true;	
				System.out.println("The Random seed generated by the Model is : " + seedNew);
				
				Log_pw.println("The Random seed generated by the Model is : " + seedNew);
				Log_pw.println(" ");
				
				engine.getDefaultRandomGenerator().setSeed(seedNew);
			}
		}
	}
	//Printing Random Seed Done*******************************************************************************************
	
	//Print the name of the experiment************************************************************************************
	before(): experimentName()
	{
		if (enableTool)
		{
			//The counter is required here as the method is called multiple times__void org.dom4j.Document.setName(String)
			//Only the first time the name of the experiment can be retrieved__PPD1_Old.SmallPopulation.setName(String)
			if (counterSetName == 0) {  
				Log_pw.println("Experiment Name : " + thisJoinPoint.getThis().getClass().getSimpleName());
				Log_pw.println(" ");
				
				Trace_pw.println("Experiment Name : " + thisJoinPoint.getThis().getClass().getSimpleName());
				Trace_pw.println(" ");
				
				System.out.println("Experiment Name : " + thisJoinPoint.getThis().getClass().getSimpleName());
				counterSetName++;	
			}
		}
	}
	
	//Printing the name of the experiment done***************************************************************************     
	
	//Print the Parameters of  the Main class****************************************************************************
	after(final Agent self, boolean callOnChangeActions): mainParameters(self, callOnChangeActions)
	{
		if (enableTool)
		{
			String PackageName = thisJoinPoint.getThis().getClass().getPackage().getName();
			String className = (PackageName + ".Main");
			boolean foundMethod = false;
			
			try {
				//Get the main class
				Class mainClass = Class.forName(className);
				//Get the methods of the main class
				Method[] mainMethods = mainClass.getMethods();
				//Get the fields of the main class
				Field[] mainFields = mainClass.getFields();
				
				String findString = "_DefaultValue_xjal";
				for (int i = 0; i < mainMethods.length; i++) {
					String searchMethod = mainMethods[i].getName().toString();
					String methodName = "";
					
					if (searchMethod.contains(findString)) {
						methodName = searchMethod.replaceAll(findString, "");
						methodName = methodName.substring(1, methodName.length());
						foundMethod = true;
						
						if (foundMethod == true) {
							for (int j = 0; j < mainFields.length; j++) {
								String searchField = mainFields[j].getName().toString();
								if (searchField.contains(methodName)) {
									String parameterName = searchField;
									
									Log_pw.println("The Parameters used in this Experiment are as follows :- ");
									Log_pw.println(" ");
									Log_pw.println("Parameter Type" + "\t\tParameter Name" + "\t\tParameter Value"); 
									Log_pw.println(mainFields[j].getType() + "\t\t\t" + mainFields[j].getName() + "\t\t\t" + mainFields[j].get(self));
									Log_pw.println(" ");
									
									System.out.println("parameter name: " + searchField);
									System.out.println("Parameter Type" + "\t\tParameter Name" + "\t\tParameter Value"); 
									System.out.println(mainFields[j].getType() + "\t\t\t" + mainFields[j].getName() + "\t\t\t" + mainFields[j].get(self));
								}
							}
						}
						foundMethod = false;
					}
				}
			} catch (Exception e) {
				e.printStackTrace();
			}  
		}
	}
	//Printing the parameters done**************************************************************************************
	
	//Tracing started**************************************************************************************
	after(Agent agt, java.lang.Object msg, int mode): sendMessageWMode(agt, msg, mode) 
	{
		if (enableTool)
		{
			String modeStr = "unknown";
			switch(mode) {
			case 1: modeStr = "ALL"; break;
			case 2: modeStr = "ALL_CONNECTED"; break;
			case 3: modeStr = "ALL_NEIGHBOURS"; break;
			case 4: modeStr = "RANDOM"; break;
			case 5: modeStr = "RADNOM_CONNECTED"; break;
			case 6: modeStr = "RANDOM_NEIGHBOUR"; break;
			}
			
			Trace_pw.println("Time: " + agt.time() + "\tAgent: "+ agt.getName() + "\tSend: "+ msg + "\tTo: " + modeStr );
			Trace_pw.println(" ");
		}
	}

	after(Agent agt, java.lang.Object msg, Agent dest): sendMessage(agt, msg, dest) 
	{ 
		if (enableTool)
		{
			Trace_pw.println("Time: " + agt.time() + "\tAgent: "+ agt.getName() + "\tSend: "+ msg + "\tTo: " + dest.getName());
			Trace_pw.println(" ");
		}
	}
	
	after(Agent agt, java.lang.Object msg, Agent sender): receiveMessage(agt, msg, sender) 
	{
		if (enableTool)
		{
			if (sender == null) {  
				Trace_pw.println("Time: " + agt.time() + "\tAgent: "+ agt.getName() + "\tReceive: "+ msg + "\tFrom: NULL");   	
				Trace_pw.println(" ");
			} else {   
				Trace_pw.println("Time: " + agt.time() + "\tAgent: "+ agt.getName() + "\tReceive: "+ msg + "\tFrom:" + sender.getName());
				Trace_pw.println(" ");
			}
		}
	}
	
	after(Agent agt, short state, boolean destination): enterAState(agt, state, destination) 
	{
		if (enableTool)
		{
			Trace_pw.println("Time: " + agt.time() + "\tEntering State: " + "\tAgent: "+ agt.getName() + "\tState: " + agt.getNameOfState(state));
			Trace_pw.println(" ");
		}
	}
	
	after(Agent agt, short state, Transition tran, boolean source, Statechart statechart): exitAState(agt, state, tran, source, statechart) 
	{
		if (enableTool)
		{
			Trace_pw.println("Time: " + agt.time() + "\tExiting State: " + "\tAgent: "+ agt.getName() + "\tState: "+ agt.getNameOfState(state) + "\tVia transition: "+ tran);
			Trace_pw.println(" ");
		}
	}
	//Tracing done ***********************************************************************************************
	
	//Final Date n Time*************************************************************************************************	
	after(): experimentCompleted()
	{
		if (enableTool)
		{
			experimentStop = true;
			try {
				Date endDate = new Date();	
				
				Calendar calendar = Calendar.getInstance();
				
				calendar.setTime(startDate);
				long milliseconds1 = calendar.getTimeInMillis();
				
				calendar.setTime(endDate);
				long milliseconds2 = calendar.getTimeInMillis();
				
				long diff = milliseconds2 - milliseconds1;
				double diffSeconds = diff / 1000.0;
				double diffMinutes = diffSeconds / 60.0;
				
				Log_pw.println("Date and Time when the experiment completes :  " + endDate);
				Log_pw.println(" ");
				Log_pw.println("Total Time elapsed in Seconds :  " + diffSeconds);
				Log_pw.println("Total Time elapsed in Minutes :  " + diffMinutes);
				Log_pw.println("__________________________________________________________________________________");
				
				System.out.println("Engine ended");	
				Log_pw.close();
				Trace_pw.close();
			}
			catch (Exception e) {
				e.printStackTrace();
			}	
		}
	}
	//Final Date n Time Done************************************************************************************
	
	//Images****************************************************************************************************
	after(): experimentStarted()
	{	
		if (enableTool)
		{
			experimentStart = true;
		}
	}
	

	after() returning(Presentation window) : getPresentation()
	{			
		if (enableTool)
		{
			if (experimentStart == true) {
				experimentStart = false;
				Rectangle rec = window.getPanel().getBounds();	
				BufferedImage captureInitial = new BufferedImage(rec.width, rec.height,BufferedImage.TYPE_INT_ARGB);
				window.getPanel().paint(captureInitial.createGraphics());
				try {
					String CPathName = (subDir + "/" + "canvasCaptureInitial.jpg");
					File canvasInitial = new File(CPathName);
					ImageIO.write(captureInitial, "png", canvasInitial);
				} catch (Exception e) {
					e.printStackTrace();
				}
			}
			
			if (experimentStop == true) {
				experimentStop = false;
				Rectangle recStop = window.getPanel().getBounds();	
				BufferedImage captureFinal = new BufferedImage(recStop.width, recStop.height,BufferedImage.TYPE_INT_ARGB);
				window.getPanel().paint(captureFinal.createGraphics());
				try {
					String CPathName = (subDir + "/" + "canvasCaptureFinal.jpg");
					File canvasFinal = new File(CPathName);
					ImageIO.write(captureFinal, "png", canvasFinal);
				} catch (Exception e) {
					e.printStackTrace();
				}
			}
		}
	}
	//Images done********************************************************************************************
	after() returning (Agent e) : getName()
	{
		if (enableTool)
		{
			System.out.println(thisJoinPoint);
			System.out.println(" className : " + thisJoinPoint.getSourceLocation().getWithinType().getCanonicalName());
			System.out.println("Name1 : " + e);
		}
	}
}