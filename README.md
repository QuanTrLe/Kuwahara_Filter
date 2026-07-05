# Kuwahara_Filter

## Summary
This project includes different versions of the Kuwahara Filter that I am implementing inside Unity for self-learning and for a passion project. Specifically the project includes four versions of the filters: the basic version, the generalized version that improves on the stylization, a version that improves the generalized version's performance, and the anisotropic version that further enhances the stylization by being aware of the image structure. For each one, there is a .cs file meant to be attached onto the camera in the scene, and a .shader file for the shader effect itself.

Currently, the versions implemented are mainly for studying and visual inspecting, not for production due to the performance of the filter itself. This video was heavily inspired and done based off the knowledge I got from [Acerola's video](https://www.youtube.com/watch?v=LDhN-JK3U9g&t=867s) and the paper released on the topic, which has been linked in the acknowledgements section.

## Filter Ouputs
Including the base image, the basic version, the optimized generalized version, and the anisotropic version

## Overview of Workings
### Basic Kuwahara Filter
The basic Kuwahara filter works by taking a pixel and a square kernel around it. The kernel is then divided into 4 sections, with each section's color getting inspected for standard deviation. The pixel then chooses the average color of the section that has the lowest deviation. This version of the filter would consequently leave square effects over the image, with square blocks of pixels having around the same color. This creates a painterly effect, which is what inspired me to do this project.

![alt text][kuwahara_basic_filter_kernel]

While the filter is easy to implement, there's also a lot of drawbacks with the most basic version, mainly due to the shape of the kernel and the way that it calculates the color after the inspection of the kernel sections. Since the square kernels creates blocky artefact it's not fully good enough if our aim is to simulate painting strokes. Additionally, the pixel colors are also vulnerable to regions with small changes since the filter only chooses the average color of one section. A note outside of this is that if two sections have the same standard deviation in color, if not handled, the pixel color can also flicker and be unpredictable.

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
6. [Kuwahara Filter Wikipedia](https://en.wikipedia.org/wiki/Kuwahara_filter) 

[kuwahara_basic_filter_kernel]: https://github.com/QuanTrLe/Kuwahara_Filter/Images/Kuwahara_square_kernel.jpg "[Basic Kuwahara Filter Kernel](https://en.wikipedia.org/wiki/Kuwahara_filter)"