# TravelingWaveRetino

## Summary
Code for retinotopic mapping stimuli (traveling wave & sweeping bar) using Psychtoolbox (http://psychtoolbox.org/) and MATLAB. Code was written to be used with fMRI.

## Contents
- `TravelingWave.m`: the main experimental code. This code requires user-defined parameters specified in the accompanying `example_` files. Run these files to call `TravelingWave.m`.
- `example_eeccen_checkerboard_attenstim.m`: example of expanding / contracting ring stimuli for mapping eccentricity space. This code uses a color checkerboard stimulus and employs a covert attention task where subjects must attend the stimulus and detect a dimming of the checkerboard at some part of the ring.
- `example_ppolar_checkerboard_attenstim.m`: example of rotating wedge stimulus for mapping polar angle space. This code uses a color checkerboard stimulus and employs a covert attention task where subjects must attend the stimulus and detect a dimming of the checkerboard at some part of the wedge.
- `images/`: folder containing checkerboard stimuli. Checkerboard stimuli come from Swisher et al. 2007 Journal of Neuroscience. [Link to article](https://pubmed.ncbi.nlm.nih.gov/17507555/) [Link to abstract](https://www.jneurosci.org/content/27/20/5326.abstract)

## Important notes about using the code
1) The code was written for use with OSX and has not been extensively tested using Windows.
2) Recent versions of OSX seem to have broken `KbCheck`. The code works if you launch MATLAB from the terminal.
3) When first running the program/PTB, you may see a solid color screen for 30s-1min. Just wait. The program will eventually load. This seems to be an issue with newer versions of OSX.

## Acknowledgements
Earlier versions of this code were used for data reported in:
1. Arcaro et al. 2009 Journal of Neuroscience. [Link to article](https://pubmed.ncbi.nlm.nih.gov/19710316/)
2. Wang et al. 2015 Cerebral Cortex. [Link to article](https://pubmed.ncbi.nlm.nih.gov/25452571/)
3. Arcaro et al. 2015 Journal of Neuroscience. [Link to article](https://pubmed.ncbi.nlm.nih.gov/26156987/)
4. Arcaro et al. 2017 Journal of Neuroscience. [Link to article](https://pubmed.ncbi.nlm.nih.gov/28674177/)
