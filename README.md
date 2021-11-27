# Edge Histogram Descriptor (EHD)

 This is a small Matlab class, that implements MPEG-7 texture descriptor "Edge Histogram Descriptor" (see paper [1]), along with improvements suggested in paper [2], particularly the semi-local features.

## Purpose

This descriptor, despite its conceptual simplicity, can give relatively good results in image retrieval tasks, and image similarity analysis.

The ability to capture different edge orientations, also possibly makes EHD suitable for Parkinson diagnosis via standard spiral test image analysis, as suggested in paper [3] since it can capture tremors, which is a common feature of Parkinson diagnosed people in their spiral drawings.
This class had been built to verify and reproduce that paper suggestions and results.

## Requirements and dependencies

This class has no external dependencies, except Matlab.

Some requirements on the input image are imposed by EHD by design. If any is violated, the class will through an exception with the explanation.

## References and papers

- [1] S. J. Park, D. K. Park, C. S. Won, "Core experiments on
MPEG-7 edge histogram descriptor" MPEG document M5984, Geneva, May, 2000.
- [2] Dong Kwon Par, Yoon Seok Jeon, Chee Sun Won, "Efficient Use of Local Edge Histogram Descriptor" ETRI Journal, vol. 24, no. 1, pp. 23-30, February 2002.
- [3] Najd Al-Yousef, Raghad Al- Saikhan, Reema Al- Gowaifly, Reem Al-Abdullatif, Felwa Al-Mutairi, Ouiem Bchir, "Parkinson's Disease Diagnosis using Spiral Test on Digital Tablets", International Journal of Advanced Computer Science and Applications, Vol. 11, No. 5, 2020.
