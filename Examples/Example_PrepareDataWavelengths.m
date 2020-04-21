function Example_PrepareDataWavelengths

%% Method 1: Individual Dataset

fNIRSTools.PrepareDataWavelengths('C:\Users\kmstu\Desktop\fNIRS_DEMO_DATA\Raw\NIRS-2019-06-14_005', 'C:\Users\kmstu\Desktop\fNIRS_DEMO_DATA\Example_PrepareDataWavelengths_1\NIRS-2019-06-14_005');
fNIRSTools.PrepareDataWavelengths('C:\Users\kmstu\Desktop\fNIRS_DEMO_DATA\Raw\NIRS-2019-06-14_006', 'C:\Users\kmstu\Desktop\fNIRS_DEMO_DATA\Example_PrepareDataWavelengths_1\NIRS-2019-06-14_006');

%% Method 2: All Datasets in Directory

fNIRSTools.PrepareDataWavelengths('C:\Users\kmstu\Desktop\fNIRS_DEMO_DATA\Raw', 'C:\Users\kmstu\Desktop\fNIRS_DEMO_DATA\Example_PrepareDataWavelengths_2');

%% Example Override (field-value pair)

fNIRSTools.PrepareDataWavelengths('C:\Users\kmstu\Desktop\fNIRS_DEMO_DATA\Raw\NIRS-2019-06-14_005', 'C:\Users\kmstu\Desktop\fNIRS_DEMO_DATA\Example_PrepareDataWavelengths_3\NIRS-2019-06-14_005', 'WAVELENGTHS_USE', [785 808 850]);

fNIRSTools.PrepareDataWavelengths('C:\Users\kmstu\Desktop\fNIRS_DEMO_DATA\Raw\NIRS-2019-06-14_005', 'C:\Users\kmstu\Desktop\fNIRS_DEMO_DATA\Example_PrepareDataWavelengths_3\NIRS-2019-06-14_005', 'WAVELENGTHS_USE', [785 850], 'OVERWRITE', true);

%% Example Override (structure)

overrides.WAVELENGTHS_USE = [785 850];
overrides.OVERWRITE = true;
fNIRSTools.PrepareDataWavelengths('C:\Users\kmstu\Desktop\fNIRS_DEMO_DATA\Raw\NIRS-2019-06-14_005', 'C:\Users\kmstu\Desktop\fNIRS_DEMO_DATA\Example_PrepareDataWavelengths_4\NIRS-2019-06-14_005', overrides);
