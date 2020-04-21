# fNIRS Tools

## PrepareDataWavelengths

Prepares data collected with the NIRScoutX 64x32 system for analysis by
creating a copy of the dataset that contains only the specified
wavelengths. By default, these are 785 and 850.

### Inputs:

	directory_search    Path to the starting point of the data search. This
                      function will process any datasets found in search
                      directory. Any directory with a _probeInfo.mat file
                      is expected to be a dataset.

	directory_output    Path to the root outout directory. The directory
                      structure in the search path will be matched.

### Overrides:

  Any parameters (fields of the p structure) may be overridden either by
  passing a structure with any number of matching fields or by passing
  any number of field-value pairs.
