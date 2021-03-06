function sct_dmri_moco_manual(data,motionPos)
%sct_dmri_moco_manual(data,motionPos)

data_basename=sct_tool_remove_extension(data,1);

% change orientation and put header
nii=load_nii(data);
save_nii_v2(nii,data);

tmp_folder=sct_tempdir;
mkdir(tmp_folder)

sct_gunzip(data,tmp_folder)
unix(['cp ' data ' ' tmp_folder]);
cd(tmp_folder)
movefile([sct_tool_remove_extension(data,0) '.nii'], 'data.nii')

% step2

sct_dmri_splitin2('data',motionPos,[1 2]);
sct_unix('fslmath data_1 -Tmean data_1_1');
sct_unix('fslmath data_2 -Tmean data_2_1');

unix(['sct_orientation -i data_1_1.nii.gz -s RPI -o data_1_1.nii.gz']);
cmd=(['sct_register_multimodal -i data_2_1.nii.gz -d data_1_1.nii.gz -p step=1,algo=slicereg2d_translation']);
sct_unix(cmd)

cmd=(['sct_apply_transfo -i data_1.nii.gz -d data_2_1.nii.gz -w ' pwd filesep 'warp_data_1_12data_2_1.nii.gz -o ' pwd filesep 'data_1_reg.nii.gz']);

sct_unix(cmd)

% files = sct_splitTandrename('data_1.nii.gz');
  files = sct_splitTandrename('data_2.nii.gz');
  
  cmd=(['sct_apply_transfo -i ' files{1} ' -d data_1_1.nii.gz -w warp_data_2_12data_1_1.nii.gz -o data_2_reg.nii.gz']);
  sct_unix(cmd)
% cmd=(['sct_apply_transfo -i ' files{1} ' -d data_2_1.nii.gz -w warp_data_1_12data_2_1.nii.gz -o data_1_reg.nii.gz']);
% sct_unix(cmd)

for ff=2:length(files)
    cmd=(['sct_apply_transfo -i ' files{ff} ' -d data_1_1.nii.gz -w warp_data_2_12data_1_1.nii.gz -o data_2_reg_tmp.nii.gz']);
    sct_unix(cmd)
    sct_unix('fslmerge -t data_2_reg.nii.gz data_2_reg.nii.gz data_2_reg_tmp.nii.gz');
end

% for ff=2:length(files)
%     cmd=(['sct_apply_transfo -i ' files{ff} ' -d data_2_1.nii.gz -w warp_data_1_12data_2_1.nii.gz -o data_1_reg_tmp.nii.gz']);
%     sct_unix(cmd)
%     sct_unix('fslmerge -t data_1_reg.nii.gz data_1_reg.nii.gz data_1_reg_tmp.nii.gz');
% end

cmd=['fslmerge -t ' data_basename '_reg data_1.nii.gz data_2_reg.nii.gz'];
sct_unix(cmd)

cd ../
unix(['rm -rf ' tmp_folder]);
