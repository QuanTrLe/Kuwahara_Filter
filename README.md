# Kuwahara_Filter

## Summary
This project includes different versions of the Kuwahara Filter that I am implementing inside Unity for self-learning and for a passion project. Specifically the project includes four versions of the filters: the basic version, the generalized version that improves on the stylization, a version that improves the generalized version's performance, and the anisotropic version that further enhances the stylization by being aware of the image structure. For each one, there is a .cs file meant to be attached onto the camera in the scene, and a .shader file for the shader effect itself.

Currently, the versions implemented are mainly for studying and visual inspecting, not for production due to the performance of the filter itself. This video was heavily inspired and done based off the knowledge I got from [Acerola's video](https://www.youtube.com/watch?v=LDhN-JK3U9g&t=867s) and the paper released on the topic, which has been linked in the acknowledgements section.

## Filter Ouputs
Including the base image, the basic version, the optimized generalized version, and the anisotropic version

## Overview of Workings
### Basic Kuwahara Filter
Workings of the basic Kuwahara filter

### Generalized Kuwahara Filter
Workings of the generalized Kuwahara filter and also it's more optimzied counterpart

### Anisotropic Kuwahara Filter
Workings of the anisotropic Kuwahara filter

## Acknowledgements
1. [This is the Kuwahara Filter - Acerola](https://www.youtube.com/watch?v=LDhN-JK3U9g&t=867s)
2. [Image and Video Abstraction by Anisotropic Kuwahara Filtering](https://www.researchgate.net/publication/220507613_Image_and_Video_Abstraction_by_Anisotropic_Kuwahara_Filtering)
3. [Anisotropic Kuwahara Filtering with Polynomial Weighting Functions](https://www.researchgate.net/publication/220862124_Anisotropic_Kuwahara_Filtering_with_Polynomial_Weighting_Functions)
4. [Sobel Operator explaination](https://homepages.inf.ed.ac.uk/rbf/HIPR2/sobel.htm)
5. [Gaussian Weight and Smoothing](https://homepages.inf.ed.ac.uk/rbf/HIPR2/gsmooth.htm)