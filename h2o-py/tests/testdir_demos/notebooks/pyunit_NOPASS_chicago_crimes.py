import sys
sys.path.insert(1, "../../../")
import h2o

def demo_chicago_crimes(ip,port):
    # Connect to a pre-existing cluster
    h2o.init(ip,port)

    # execute ipython notebook
    h2o.ipy_notebook_exec(h2o.locate("h2o-py/demos/chicago_crimes.ipynb"),save_and_norun=False)

if __name__ == "__main__":
    h2o.run_test(sys.argv, demo_chicago_crimes)




