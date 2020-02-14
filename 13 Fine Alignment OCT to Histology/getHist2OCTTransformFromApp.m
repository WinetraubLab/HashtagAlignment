function [histologyToOCTT, octPixelSize_um, topLeftCornerXmm, topLeftCornerZmm] = getHist2OCTTransformFromApp(app)
    
% Get OCT Volume Pixel size
x = app.jsons.sectionIterationConfig.data_um.x.values;
z = app.jsons.sectionIterationConfig.data_um.z.values;
dx = diff(x(1:2));
dz = diff(z(1:2));
if std(diff(x))>1e-3 || std(diff(z))>1e-3 || dx ~= dz
    error('Unimplemented here');
end

octPixelSize_um = dx;

histologyToOCTT = knobesToTransform( ...
    app.HistolgyScaleumpixSpinner.Value, ...
    app.RotationdegSpinner.Value,...
    app.XTranslationumSpinner.Value,...
    app.ZTranslationumSpinner.Value,...
    octPixelSize_um);

topLeftCornerXmm = x(1)/1e3;
topLeftCornerZmm = z(1)/1e3;