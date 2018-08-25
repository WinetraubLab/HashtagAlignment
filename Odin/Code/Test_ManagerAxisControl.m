%
% File: Test_ManagerAxisControl.m
% -------------------
% Author: Erick Blankenberg
% Date 8/1/2018
% 
% Description:
%   This script tests out the X-Y-Z axis control system.
%

clear all;
close all;

stageUnit = Manager_AxisControl();
stageUnit.homeZ();
while(1)
    stageUnit.getZ()
end

