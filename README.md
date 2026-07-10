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

While the filter is easy to implement, there's also a lot of drawbacks with the most basic version, mainly due to the shape of the kernel and the way that it calculates the color after the inspection of the kernel sections. Since the square kernels creates blocky artefact it's not fully good enough if our aim is to simulate painting strokes. Additionally, the pixel colors are also vulnerable to regions with small changes since the filter only chooses the average color of one section. A note outside of this is that if two sections have the same standard deviation in color, the pixel color can also flicker and be unpredictable when those two sections happen to have different mean colors despite the same color standard deviation. To fix this you can do something simple as taking the average of the colors from the sectors that have the minimum deviation.

* Insert output image compared to test image here

### Generalized Kuwahara Filter
To fix the stylization issues of the previous version, the generalized kuwahara filter instead uses a circular kernel shape, along with Gaussian weighting for the colors from each sector instead of just choosing one. The circular kernel is divided into 8 sections instead of 4 like before, making it so that the filter is much more versatile to be able to adapt to the finer details of the image instead of colors being clumped into square shapes as before. This effect is much more noticeable when looking at hair or fine details as such. This version also uses a gaussian weight and take into account the colors of all sections instead of just choosing one section. This is done by using the inverse of the color deviation of the section, making it so that the higher the deviation of the section, the lower the weight the section will have when it comes to the final color calculation. As a result, the filter is again more adaptable to the image and the patches of color blends better too.

However, this version of the filter does have two glaring issues. First of which, is the performance. Specifically, when we do the calculations for one pixel, we would be doing a gaussian weight for each of the section of the kernel around it. This would come up to 8 gaussian weights per pixel and the performance would only get worse the larger the kernel size becomes because there would be more pixels per weight calculation. Another issue is that while the stylization is definitely an improvement compared to the basic version of the filter, this version still fails when it comes to extreme angles or details, due to our set kernel size. As Acerola said in his video, it's like trying to paint a painting with only a single brush size. 

To fix the issue of the performance, the Anisotropic Kuwahara filter did propose to use a polynomial weighting for each sector instead of using gaussian weighting. This would drastically reduce the time taken for the filter to calculate thanks to the elimination of square roots in the equation while allowing the visual aspects to remain relatively the same. For my current implementation of the polynomial weighting version, it requires 2 passes instead of 1 to be able to achieve the same visual results of the generalized one. The 2 passes results in an average 4.5 fps for me and 8.5 if it only does 1 pass, which is still, technically, an improvement over 3fps of the original generalized version.    

![alt text][polynomial_approx_weighting]

### Anisotropic Kuwahara Filter
Workings of the anisotropic Kuwahara filter

## Acknowledgements
1. [This is the Kuwahara Filter - Acerola](https://www.youtube.com/watch?v=LDhN-JK3U9g&t=867s)
2. [Image and Video Abstraction by Anisotropic Kuwahara Filtering](https://www.researchgate.net/publication/220507613_Image_and_Video_Abstraction_by_Anisotropic_Kuwahara_Filtering)
3. [Anisotropic Kuwahara Filtering with Polynomial Weighting Functions](https://www.researchgate.net/publication/220862124_Anisotropic_Kuwahara_Filtering_with_Polynomial_Weighting_Functions)
4. [Sobel Operator explaination](https://homepages.inf.ed.ac.uk/rbf/HIPR2/sobel.htm)
5. [Gaussian Weight and Smoothing](https://homepages.inf.ed.ac.uk/rbf/HIPR2/gsmooth.htm)
6. [Kuwahara Filter Wikipedia](https://en.wikipedia.org/wiki/Kuwahara_filter) 
7. [Ellipse Wikipedia](https://en.wikipedia.org/wiki/Ellipse)

[kuwahara_basic_filter_kernel]: https://github.com/QuanTrLe/Kuwahara_Filter/blob/main/Images/Kuwahara_square_kernel.jpg "Basic Kuwahara Filter Kernel: From [7]"
[polynomial_approx_weighting]: https://github.com/QuanTrLe/Kuwahara_Filter/blob/main/Images/Polynomial_approx_weighting.png "Polynomial Weighting Approximation: From [3]"