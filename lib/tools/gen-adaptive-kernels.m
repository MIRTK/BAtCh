% Adaptive Kernel Width algorithm (mainly proposed by Ahmed Serag)
% Author: Lisa Koch
% Author: Antonis Makropoulos
% Creation date: 9.1.2013
% Updated date: 1.12.2016

%% 1a. Input csv file containing ID, age at scan (excluded subjects removed)

% This is the whole file.
% Column "T2 proc TC" contains a 1 if preprocessed image is available.
% age_filename = 'etc/bages_ages.csv';
% subjs_filename = 'etc/sub.lst';
age_filename = 'bages_ages.csv';
subjs_filename = 'subjs-with-T1-excluded-single-extra.csv';

mkdir('results')
fOut = 'results/group_fixed.csv';
fsOut='results/sizes_fixed.csv';
aOut = 'results/group_adaptive.csv';
asOut='results/sizes_adaptive.csv';
subjsOut='results/subjs_retained.csv';
ageGroups	= (36:44);		% this is the range of the existing neonatal atlas
k = 0;              % tolerance, might be adjusted
d_sigma = 0.01;     % step size for sigma adjustment


scrsz = [1 1 768 768];
set(0,'DefaultAxesFontName', 'Times New Roman')
set(0,'DefaultAxesFontSize', 15)
set(0,'DefaultAxesFontWeight','bold');

fhandle = fopen(age_filename);
C = textscan( fhandle, '%s %f %f', 'delimiter', ' ', 'EmptyValue', 0, 'HeaderLines', 0);
fclose(fhandle);

ids	= C{1,1};
bages = C{1,2};
ages = C{1,3};

if subjs_filename 
    fhandle = fopen(subjs_filename);
    S = textscan( fhandle, '%s', 'delimiter', ',', 'EmptyValue', 0, 'HeaderLines', 0);
    fclose(fhandle);
    S=S{:};

    inds=[];
    for i=1:length(S)
      inds(i)=find(strcmp(ids,S{i}));
    end

    ids=ids(inds);
    bages=bages(inds);
    ages=ages(inds);
end



%% visualize age distribution of included subjects


dageGroups=round(min(ages)):round(max(ages));
diffGroups=[1:10];

p= repmat( ages-bages, 1, size(dageGroups,2) );
b= repmat( ages, 1, size(dageGroups,2) ) -repmat(dageGroups, size(ages,1), 1);
p(abs(b)>0.5)=nan;

L={};
for n=1:length(dageGroups)
[nelements,xcenters] = hist(p(:,n),diffGroups);
N(:,n)=nelements;
end

for n=1:length(diffGroups)
L{n}=num2str(n);
end

f=figure('Position',scrsz);
set(f,'PaperUnits','inches','PaperPosition',[0 0 12 9]);
bar(dageGroups,N','stacked')
legend(L)

xlabel('age at scan')
ylabel('number of scans')
title('diff age at scan - age at birth')

print(f,'-depsc','-r200','results/diff_ages.eps');
close(f)

% exlude subjects
exclude=union(find(ages-bages>4),find(ages<35));
ages(exclude)=[];
bages(exclude)=[];
ids(exclude)=[];

xlimrange=[min(ages)-1,max(ages)+1];

cell2csv( subjsOut, ids, ',');

%% visualize age distribution of included subjects

f=figure();
binMeans	= min(ages):1:max(ages);

hist( ages, binMeans)
xlim( xlimrange )
title( 'Age distribution of neonatal data set' )
xlabel( 'Age at scan [weeks PMA]')
ylabel( 'Frequency' )
grid on
print(f,'-depsc','-r200','results/hist_ages.eps');
close(f)






%% 3. Adaptive kernel width algorithm

% w(ti,t) = 1/(sigma*sqrt(2*pi)) * exp( -(ti - t)^2 / (2*sigma^2) )

% Init 1. Initialize with sigma = 1, compute all weights.

% sigma		= 0.5;
sigma		= 1;
sigmas		= repmat(sigma, 1, size(ageGroups, 2));
t_mean		= repmat( ageGroups, size(ages,1), 1);
t		= repmat( ages, 1, size(ageGroups,2) );
weights		= 1/(sigma*sqrt(2*pi)) * exp( -(t - t_mean).^2 / (2*sigma^2) );



%%

% Init 2. Retain all subjects with w >= 0.35wmax, compute median number of
%    subjects per interval

% setOfSubjects_final = weights >= 0.35*max(max(weights));
setOfSubjects_final = weights >= 0.001;

% retain all subjects within age range t+-3
% upperLimit	= bsxfun( @le, t, (ageGroups+3) );
% lowerLimit	= bsxfun( @ge, t, (ageGroups-3) );
% setOfSubjects_final = setOfSubjects_final .* upperLimit;
% setOfSubjects_final = setOfSubjects_final .* lowerLimit;


% compute the sum along each column: number of subjects selected per
% agegroup
nSubjects = sum(setOfSubjects_final);
n_median = median(nSubjects);

dlmwrite(fsOut,[nSubjects;sigmas])

result = weights .* setOfSubjects_final; % nonzero entries for selected subjects only

%% visualize
selectedAges	= t .* setOfSubjects_final;
selectedAges(selectedAges==0)=nan;

f=figure();
hist(selectedAges, ageGroups)
xlim( xlimrange )
print(f,'-depsc','-r200',strrep(fOut,'.csv','.eps'));

%% 5. Store results in csv files

% create a file containing real IDs and weights only for selected subjects,
% otherwise 0.

% patch together final cell:

header = cat(2, 'ID', 'BirthAge', num2cell(ageGroups));
sigma_entries = cat(2, '--', '--', num2cell(sigmas));

left = ids;
middle = num2cell(ages);
right = num2cell( result );
bottom = cat(2, left, middle, right);

whole = cat(1, header, sigma_entries, bottom);
cell2csv( fOut, whole, ',');



%%

% algorithm

% sigmas: 1xm (kernel width for each agegroup)
sigmas = repmat(sigma, 1, size(ageGroups, 2));

for i = 1:size(ageGroups,2)
    
     t = ageGroups(i);
             
     if nSubjects(i) >n_median
         % decrement sigma and remove subjects until acceptable (tolerance
         % k)
         
         go_again = true;
         while go_again
             sigma = sigmas(i) - d_sigma;
             sigmas(i) = sigma;

             weights(:,i) = 1/(sigma*sqrt(2*pi)) * exp( -(ages - t).^2 ./ (2*sigma^2) );

             % setOfSubjects_final(:,i) = weights(:,i) >= 0.35*max(weights(:,i));
             setOfSubjects_final(:,i) = weights(:,i) >= 0.001;
             nSubjects(i) = sum(setOfSubjects_final(:,i));
             
             go_again = nSubjects(i) > n_median + k;
         end
     end
     sigmamore=sigma;
     diffmore=abs(nSubjects(i)-n_median);
     
     if nSubjects(i) < n_median
         % decrement sigma and remove subjects until acceptable (tolerance
         % k)
         
         % TODO: Use additional brain volume constraint
         
         go_again = true;
         while go_again
             sigma = sigmas(i) + d_sigma;
             sigmas(i) = sigma;

             weights(:,i) = 1/(sigma*sqrt(2*pi)) * exp( -(ages - t).^2 ./ (2*sigma^2) );

             % setOfSubjects_final(:,i) = weights(:,i) >= 0.35*max(weights(:,i));
             setOfSubjects_final(:,i) = weights(:,i) >= 0.001;
             nSubjects(i) = sum(setOfSubjects_final(:,i));
             
             go_again = nSubjects(i) < n_median - k;
         end
     end     
     
%      if abs(nSubjects(i)-n_median) > diffmore
%          sigma=sigmamore;
%          sigmas(i) = sigma;
%          weights(:,i) = 1/(sigma*sqrt(2*pi)) * exp( -(ages - t).^2 ./ (2*sigma^2) );
%          setOfSubjects_final(:,i) = weights(:,i) >= 0.001;
%          nSubjects(i) = sum(setOfSubjects_final(:,i));
%      end
     
      d=nSubjects(i)-n_median;
      if d>0
        nz=find(setOfSubjects_final(:,i));
        [sw si]=sort(weights(nz, i));
        setOfSubjects_final(nz(si(1:d)),i) = 0;
        nSubjects(i) = sum(setOfSubjects_final(:,i));
      end  
end

%% 4. Plot results 

n_median
sigmas
nSubjects

result = weights .* setOfSubjects_final; % nonzero entries for selected subjects only

size(result)


%% visualize
t = repmat( ages, 1, size(ageGroups,2) );
selectedAges	= t .* setOfSubjects_final;
selectedAges(selectedAges==0)=nan;

f=figure(); 
hist(selectedAges, ageGroups)
xlim( xlimrange )
print(f,'-depsc','-r200',strrep(aOut,'.csv','.eps'));

f=figure(); 
hold all;
x = (ageGroups(1)-4 : 0.01 : ageGroups(end)+4);
my = 0;
cm=colormap();
for i = 1:size(ageGroups,2)
    y = 1/(sigmas(i)*sqrt(2*pi)) * exp( -(x - ageGroups(i)).^2 / (2*sigmas(i)^2) );
    my = max(my,max(y));
    plot(x,y,'color',cm(floor(i/length(ageGroups)*length(cm)),:) ,'LineWidth',2);
end   
xlim( [min(x),max(x)] )
xlabel('age at scan');
print(f,'-depsc','-r200',strrep(aOut,'.csv','_2.eps'));


%% 5. Store results in csv files

% create a file containing real IDs and weights only for selected subjects,
% otherwise 0.
% patch together final cell:

header = cat(2, 'ID', 'BirthAge', num2cell(ageGroups));
sigma_entries = cat(2, '--', '--', num2cell(sigmas));

left = ids;
middle = num2cell(ages);
right = num2cell(result);
bottom = cat(2, left, middle, right);

whole = cat(1, header, sigma_entries, bottom);
cell2csv( aOut, whole, ',');

dlmwrite(asOut,[nSubjects;sigmas])

close all