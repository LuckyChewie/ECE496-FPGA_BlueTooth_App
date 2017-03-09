package com.example.hannahkwon.bluetooth1;

import android.graphics.Color;
import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import com.androidplot.Plot;
import com.androidplot.util.Redrawer;
import com.androidplot.xy.BoundaryMode;
import com.androidplot.xy.LineAndPointFormatter;
import com.androidplot.xy.PanZoom;
import com.androidplot.xy.SimpleXYSeries;
import com.androidplot.xy.XYPlot;

import java.util.concurrent.locks.ReentrantLock;

/**
 * Created by HannahKwon on 2017-01-18.
 */

public class GraphFragment extends Fragment {
    private static String TAG = null;

    private XYPlot plot;

    private SimpleXYSeries ISE1_Series = null;
    private SimpleXYSeries ISE2_Series = null;

    private Redrawer redrawer;

    private static ReentrantLock DataLock = null;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        ISE1_Series = new SimpleXYSeries(SimpleXYSeries.ArrayFormat.Y_VALS_ONLY, "ISE1_Series");
        ISE2_Series = new SimpleXYSeries(SimpleXYSeries.ArrayFormat.Y_VALS_ONLY, "ISE2_Series");

        DataLock = new ReentrantLock();

        TAG = getTag();
        Log.d(TAG, "TAG is " + TAG);
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container,
                             Bundle savedInstanceState) {
        // Inflate the layout for this fragment
        Log.d(TAG, "Creating views for " + TAG);
        View view = inflater.inflate(R.layout.graph_fragment, container, false);

        plot = (XYPlot) view.findViewById(R.id.plot);
        if(plot == null)
            Log.d(TAG, "plot is null!");

        plot.setRenderMode(Plot.RenderMode.USE_BACKGROUND_THREAD);

        LineAndPointFormatter ISE1_format = new LineAndPointFormatter(Color.RED, Color.RED, null, null);
        LineAndPointFormatter ISE2_format = new LineAndPointFormatter(Color.BLUE, Color.BLUE, null, null);

        // disabling legends
        ISE1_format.setLegendIconEnabled(false);
        ISE2_format.setLegendIconEnabled(false);

        plot.addSeries(ISE1_Series, ISE1_format);
        plot.addSeries(ISE2_Series, ISE2_format);

        PanZoom.attach(plot);   // enable zooming

        // Sets up range of Y-axis
        //TODO Need to be deleted
        plot.setRangeBoundaries(170, 260, BoundaryMode.FIXED);

//        plot.addListener(new PlotListener() { // to synchronize data with rendering loop
//            @Override
//            public void onBeforeDraw(Plot source, Canvas canvas) {
//                // write-lock each active series for writes
////                Log.d(TAG, "Before redraw");
//                DataLock.lock();
//            }
//
//            @Override
//            public void onAfterDraw(Plot source, Canvas canvas) {
//                // unlock any locked series
////                Log.d(TAG, "Done redraw");
//                DataLock.unlock();
//            }
//        });

        // set a redraw rate of 85 Hz (at every 12 ms)
        redrawer = new Redrawer(plot, 150, true);

        return view;
    }

    @Override
    public void onViewCreated(View view, Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
    }

    @Override
    public void onDestroy() {
        redrawer.finish();
        super.onDestroy();
    }

    public synchronized void addData(int ISE1_val, int ISE2_val, int Temp_val) {
//        Log.d(TAG, "Adding following data into corresponding series: " + ISE1_val + ", "
//                + ISE2_val);
        // adding data into corresponding series

//                    Log.d(TAG, "Current ISE1: " + ISE1_Series.getyVals().toString());
//                    Log.d(TAG, "Current ISE2: " + ISE2_Series.getyVals().toString());
        ISE1_Series.addLast(null, ISE1_val);
        ISE2_Series.addLast(null, ISE2_val);


//                Log.d(TAG, "Updated ISE1: " + ISE1_Series.getyVals().toString());
//                    Log.d(TAG, "Updated ISE2: " + ISE2_Series.getyVals().toString());

        if(Temp_val >= Constants.TEMP_THRESHOLD) {
//                        Log.d(TAG, "Temp is above threshold");
            plot.getGraph().getGridBackgroundPaint().setColor(Color.GREEN);
        }
        else{
//                        Log.d(TAG, "Temp is below threshold");
            plot.getGraph().getGridBackgroundPaint().setColor(Color.WHITE);
        }

        return;
    }

    public void clear() {
        int i = ISE1_Series.size();
        int j =100;

        Log.d(TAG, "ISE series size is " + i);
        for (; j > 0; j--) {
            Log.d(TAG, "Current ISE: " + ISE1_Series.getY(i - j).toString() + ", " + ISE2_Series.getY(i - j).toString());
        }
        Log.d(TAG, "Clearing up the ISE series and graph");
        plot.getGraph().getGridBackgroundPaint().setColor(Color.WHITE);
        plot.clear();
    }
}
