package com.example.hannahkwon.bluetooth1;

import android.os.Environment;
import android.support.v4.app.FragmentActivity;
import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;

/**
 * Created by HannahKwon on 2016-10-13.
 */
public class FileManager {
    private static final String TAG = "BluetoothService";

    private FragmentActivity mActivity;
//    private Handler mHandler;

    private final String PARENT_DIR;
    private static String path = null;

    public FileManager(FragmentActivity ac){
        mActivity= ac;

        PARENT_DIR = mActivity.getString(R.string.app_name);
//        mHandler = h;
    }

    /*
    * Checks if external storage is available for read and write
    */
    public boolean isExternalStorageAvailable() {
        String state = Environment.getExternalStorageState();
        if (Environment.MEDIA_MOUNTED.equals(state)) {
            return true;
        }
        return false;
    }

    /*
    * Creates parent directory for storage if it is not there
    * Returns true if the parent storage is created or already exists
    */
    public boolean createStorageDir() {
        path = Environment.getExternalStorageDirectory().getAbsolutePath() + File.separator + PARENT_DIR;
        File file = new File(path);
        if(!file.exists()) {
            try {
                if(file.mkdir()) {
                    Log.d(TAG, "Parent directory is created");
                    return true;
                }
                else {    // failed creating parent directory
                    Log.d(TAG, "Failed creating parent directory for storage");
                    return false;
                }
            } catch (Exception e) {
                Log.e(TAG,"Failed creating parent directory for storage", e);
            }
        }
        Log.d(TAG, "File already exists");
        return true;
    }


    /*
    * Check if the given file name already exists
    */
    public boolean checkFileExists(String fileName) {
        File file = new File(path + File.separator + fileName + ".txt");
        if (file.exists())
            return true;
        return false;
    }

    /*
    * Saves the received data into file with the given file name
    */
    public boolean saveFile(String fileName, String data) {
        File file = new File(path + File.separator + fileName + ".txt");

        byte[] dataToSave = data.getBytes();

        try{
            FileOutputStream fos = new FileOutputStream(file);
            fos.write(dataToSave);
            fos.close();
        } catch (Exception e) {
            Log.e(TAG,"Failed saving data", e);
            return false;
        }
        return true;
    }
}