package water.api;

import hex.SplitFrame;
import water.Key;
import water.api.KeyV3.FrameKeyV3;

public class SplitFrameV3 extends JobV3<SplitFrame, SplitFrameV3> {
  @API(help="Dataset")
  public FrameKeyV3 dataset;

  @API(help="Split ratios - resulting number of split is ratios.length+1")
  public double[] ratios;

  @API(help="Destination keys for each output frame split.", direction = API.Direction.INOUT)
  public FrameKeyV3[] destination_frames;

  @API(help="Whether to create binary weight vectors for each split")
  public boolean make_weights;

  @API(help="Scheme to weight vectors for each split", values = { "Random", "Piecewise"})
  public SplitFrame.SamplingScheme sampling_scheme;

  @API(help="Seed for random number generator")
  public long  seed;

  @Override public SplitFrame createImpl() {
    return new SplitFrame(Key.make(), "SplitFrame job");
  }
}
