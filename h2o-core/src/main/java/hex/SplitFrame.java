package hex;

import jsr166y.CountedCompleter;
import water.*;
import water.fvec.*;
import water.util.ArrayUtils;

import static water.util.FrameUtils.generateNumKeys;
import water.util.RandomUtils;

import java.util.Random;

/**
 * Split given frame based on given ratio.
 *
 * If single number is given then it splits a given frame into two frames (FIXME: will throw exception)
 * if N ratios are given then then N-splits are produced.
 */
public class SplitFrame extends Transformer<SplitFrame> {
  /** Input dataset to split */
  public Frame _dataset;
  /** Split ratios */
  public double[] _ratios;
  /** Output destination keys. */
  public Key<Frame>[] _destination_frames;

  public boolean _make_weights = true;
  public SplitFrame.SamplingScheme _sampling_scheme = SamplingScheme.Random;
  public long _seed = new Random().nextLong();

  public enum SamplingScheme {
    Random, Piecewise, Modulo
  }

  public SplitFrame() { this(Key.make()); }
  public SplitFrame(Key<SplitFrame> dest) { this(dest, "SplitFrame job"); }
  public SplitFrame(Key<SplitFrame> dest, String desc) { super(dest, desc); }

  @Override
  public SplitFrame execImpl() {
    if (_ratios.length < 0) throw new IllegalArgumentException("No ratio specified!");
    if (_ratios.length > 100) throw new IllegalArgumentException("Too many frame splits demanded!");
    // Check the case for single ratio - FIXME in /4 version change this to throw exception
    for (double r : _ratios)
      if (r <= 0.0) new IllegalArgumentException("Ratio must be > 0!");
    if (_ratios.length == 1)
      if (_ratios[0] < 0.0 || _ratios[0] > 1.0) throw new IllegalArgumentException("Ratio must be between 0 and 1!");
    if (_destination_frames != null &&
            !((_ratios.length == 1 && _destination_frames.length == 2) || (_ratios.length == _destination_frames.length)))
      throw new IllegalArgumentException("Number of destination keys has to match to a number of split ratios!");
    // If array of ratios is given scale them and take first n-1 and pass them to FrameSplitter
    final double[] computedRatios;
    if (_ratios.length > 1) {
      double sum = ArrayUtils.sum(_ratios);
      if (sum <= 0.0) throw new IllegalArgumentException("Ratios sum has to be > 0!");
      computedRatios = new double[_ratios.length - 1];
      for (int i = 0; i < _ratios.length - 1; i++) computedRatios[i] = _ratios[i] / sum;
    } else {
      computedRatios = _ratios;
    }

    // Create destination keys if not specified
    if (_destination_frames == null) _destination_frames = generateNumKeys(_dataset._key, computedRatios.length + 1);

    H2O.H2OCountedCompleter hcc = new H2O.H2OCountedCompleter() {
      @Override
      protected void compute2() {
        if (!_make_weights) {
          FrameSplitter fs = new FrameSplitter(this, _dataset, computedRatios, _destination_frames, _key);
          H2O.submitTask(fs);
        } else {
          Frame frames[] = new Frame[_ratios.length+1];
          Vec[] weights = new Vec[_ratios.length+1];
          for (int i=0;i<frames.length;++i) {
            weights[i] = _dataset.anyVec().makeZero();
          }

          // Create binary weights
          new MRTask() {
            @Override
            public void map(Chunk[] cs) {
              Random rng = RandomUtils.getRNG(_seed + cs[0].start());
              for (int i=0; i<cs[0]._len; ++i) {
                int which = -1;
                if (_sampling_scheme == SamplingScheme.Random)
                  which = rng.nextInt(cs.length);
                else if (_sampling_scheme == SamplingScheme.Modulo)
                  which = (int)(cs[0].start()+i)%cs.length; //FIXME - requires num-fold parameter
                else if (_sampling_scheme == SamplingScheme.Piecewise) {
                  double rel_pos = (double) (cs[0].start() + i) / (double)_fr.numRows();
                  double sum=0;
                  for (int c=0; c<cs.length-2; ++c) {
                    if (rel_pos >= sum && rel_pos < sum + computedRatios[c]) {
                      which = c;
                    }
                    sum+=computedRatios[c];
                  }
                  if (which == -1) which = cs.length-1;
                }
                cs[which].set(i, 1);
              }
            }
          }.doAll(weights);

          for (int i=0;i<frames.length;++i) {
            DKV.put(weights[i]);
            frames[i] = new Frame(_destination_frames[i], _dataset.names().clone(), _dataset.vecs().clone());
            frames[i].add("weight", weights[i]);
            DKV.put(frames[i]);
          }
        }
      }

      @Override
      public void onCompletion(CountedCompleter caller) {
        if (!_make_weights) {
          FrameSplitter fs = (FrameSplitter) caller;
          Job j = DKV.getGet(_key);
          // Mark job as done
          // FIXME: the FrameSPlitter does not follow semantics of exception propagation
          if (fs.getErrors() != null) j.failed(fs.getErrors()[0]);
          else j.done();
        } else {
        }
      }

      @Override
      public boolean onExceptionalCompletion(Throwable ex, CountedCompleter caller) {
        // Mark job as failed in this case
        ((Job) DKV.getGet(_key)).failed(ex);
        return false;
      }
    };
    return (SplitFrame) start(hcc, computedRatios.length + 1);
  }
}
