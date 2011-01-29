classdef prtAction
    % prtAction - Base class for PRT components.
    %
    %   Classification, regression and feature selection techniques are all
    %   sub-classes of prtAction.
    %
    %   All prtAction objects have the following properties:
    %
    %   name                 - Descriptive name for prtAction object
    %   nameAbbreviation     - Shortened name for prtAction object
    %   isSupervised         - Indicates whether or not object requires
    %                          training
    %   isTrained            - Indicates whether the current prtAction 
    %                          object has been trained                          
    %   isCrossValidateValid - Flag indicating whether or not
    %                          cross-validation is a valid operation on 
    %                          this prtAction object.
    %   verboseStorage       - Flag to allow or disallow verbose storage
    %   DataSetSummary       - A struct, set during training, containing
    %                          information about the training data set
    %   DataSet              - A prtDataSet, containing the training data,
    %                          only used if verboseStorage is true
    %   UserData             - A struct containing user specified data
    %
    %   All prtAction objects have the following methods:
    %
    %   train             - Train the prtAction object using a prtDataSet
    %   run               - Evaluate the prtAction object on a prtDataSet
    %   runOnTrainingData - Evaluate the prtAction object on a prtDataSet
    %                       during training prior to training of other
    %                       prtActions within a prtAlgorithm
    %   crossValidate     - Cross-validate a prtAction object using a 
    %                       labeled prtDataSet and cross-validation keys.
    %   kfolds            - K-folds cross-validate a prtAction object using
    %                       a labeled prtDataSet
    %
    % See Also: prtAction/train, prtAction/run, prtAction/crossValidate,
    % prtAction/kfolds, prtClass, prtRegress, prtFeatSel, prtPreProc,
    % prtDataSetBase
    
    properties (Abstract, SetAccess = private)
        % Descriptive name of prtAction object.
        name 
        
        %  Shortened name for the prtAction object.
        nameAbbreviation 
        
        % Specifies if prtAction object requires training.
        isSupervised % Logical, requires training data to run
    end
    
    properties (Hidden = true)
        % A logical to specify if modified feature names should be stored
        % even if no feature names were specified for the dataset
        verboseFeatureNames = true;
        
        % A tag that can be used to reference a specific action within a
        % prtAlgorithm
        tag = '';
    end
    
    methods (Hidden = true)
        function dataSet = updateDataSetFeatureNames(obj,dataSet)
            if isa(dataSet,'prtDataSetStandard') && (dataSet.hasFeatureNames || obj.verboseFeatureNames)
                fNames = dataSet.getFeatureNames;
                fNames = obj.updateFeatureNames(fNames);
                if ~isempty(fNames) %it's possible that the feature set is *empty*; in which case, don't bother
                    dataSet = dataSet.setFeatureNames(fNames);
                end
            end
        end
    end
    
    methods (Hidden = true)
        function featureNames = updateFeatureNames(obj,featureNames) %#ok<MANU>
            %Default: do nothing
        end
    end
    
    properties (SetAccess = protected)
        % Specifies if prtAction object has been trained.
        isTrained = false;
        %   Set automatically in prtAction.train().
        
        % Structure that summarizes prtDataSet.
        DataSetSummary = [];
        %   Produced by prtDataSet.summarize() and stored in
        %   prtAction.train(). Used to characterize the dataset for
        %   plotting when prtAction.verboseStorage == false
        
        %  The training prtDataSet, only stored if verboseStorage is true. 
        DataSet = []; 
         %   Only stored if prtAction.verboseStorage == true. Otherwise it
        %   is empty.
        
        % Indicates whether or not cross-validation is a valid operation
        isCrossValidateValid = true;
    end
    
    properties
        % Specifies whether or not to store the training prtDataset.
        % If true the training prtDataSet is stored internally prtAction.DataSet.
        verboseStorage = true;
        
        
        % User specified data
        UserData = [];
        %   Some prtActions store additional information from
        %   prtAction.run() as a structure in prtAction.UserData()
    end
    
    methods (Abstract, Access = protected, Hidden = true)
        % prtAction.trainAction() - Primary method for training a prtAction
        %   Obj = prtAction.trainAction(Obj,DataSet)
        Obj = trainAction(Obj, DataSet)
        
        % prtAction.runAction() - Primary method for evaluating a prtAction
        %   DataSet = runAction(Obj, DataSet)
        DataSet = runAction(Obj, DataSet)
    end
        
    methods (Hidden)
        function Obj = plus(in1,in2)
            if isa(in2,'prtAlgorithm')
                Obj = in2 - in1; % Use prtAlgorithm (use MINUS to flip left/right)
            elseif isa(in2,'prtAction') && (isa(in2,'prtAction') || all(cellfun(@(x)isa(x,'prtAction'),in2)))
                Obj = prtAlgorithm(in1) + prtAlgorithm(in2);
            else
                error('prt:prtAction:plus','prtAction.plus is only defined for second inputs of type prtAlgorithm or prtAction, but the second input is a %s',class(in2));
            end
        end
        
        function Obj = mrdivide(in1,in2)
            if isa(in2,'prtAlgorithm')
                Obj = in2 \ in1; % Use prtAlgorithm(use MLDIVIDE to flip left/right)
            elseif isa(in2,'prtAction')
                Obj = prtAlgorithm(in1) / prtAlgorithm(in2);
            else
                error('prt:prtAction:mrdivide','prtAction.mrdivide is only defined for second inputs of type prtAlgorithm or prtAction, but the second input is a %s',class(in2));
            end
        end
        
        function DataSetOut = runOnTrainingData(Obj, DataSetIn)
            % RUNONTRAININGDATA  Run a prtAction object on a prtDataSet
            % object during training of a prtAlgorithm
            %
            %   OUTPUT = OBJ.run(DataSet) runs the prtAction object using
            %   the prtDataSet DataSet. OUTPUT will be a prtDataSet object.
            DataSetOut = preRunProcessing(Obj, DataSetIn);
            DataSetOut = runActionOnTrainingData(Obj, DataSetOut);
            DataSetOut = postRunProcessing(Obj, DataSetIn, DataSetOut);
        end
    end
    methods
        function Obj = train(Obj, DataSet)
            % TRAIN  Train a prtAction object using training a prtDataSet object.
            %
            %   OBJ = OBJ.train(DataSet) trains the prtAction object using
            %   the prtDataSet DataSet
            
            if ~isscalar(Obj)
                error('prt:prtAction:NonScalarAction','train method expects scalar prtAction objects, prtAction provided was of size %s',mat2str(size(Obj)));
            end
            if ~isa(DataSet,'prtDataSetBase')
                error('prt:prtAction:prtDataSetBase','DataSet provided to prtAction %s''s train() is not a prtDataSetBase, DataSet is a %s',class(Obj),class(DataSet));
            end
            if Obj.isSupervised && ~DataSet.isLabeled
                error('prt:prtAction:supervisedActionUnLabeledDataSet','The action of type %s is supervised, but the dataSet of type %s, is not labeled',class(Obj),class(DataSet));
            end
                
            % Default preTrainProcessing() stuff
            Obj.DataSetSummary = summarize(DataSet);
            
            %preTrainProcessing should make sure Obj has the right
            %verboseStorage
            Obj = preTrainProcessing(Obj,DataSet);
            if Obj.verboseStorage
                Obj.DataSet = DataSet;
            end
            
            Obj = trainAction(Obj, DataSet);
            Obj.isTrained = true;
            Obj = postTrainProcessing(Obj,DataSet);
        end
        
        function DataSetOut = run(Obj, DataSetIn)         
            % RUN  Run a prtAction object on a prtDataSet object.
            %
            %   OUTPUT = OBJ.run(DataSet) runs the prtAction object using
            %   the prtDataSet DataSet. OUTPUT will be a prtDataSet object.
            
            if ~Obj.isTrained
                error('prtAction:run:ActionNotTrained','Attempt to run a prtAction of type %s that was not trained',class(Obj));
            end
            if isnumeric(DataSetIn)
                try
                   DataSetIn = prtDataSetStandard(DataSetIn); 
                catch %#ok<CTCH>
                    error('prt:prtAction:prtDataSetBase','DataSet provided to prtAction %s''s run() was a prtDataSetBase, DataSet is a %s',class(Obj),class(DataSetIn));
                end
            elseif ~isa(DataSetIn,'prtDataSetBase')
                error('prt:prtAction:prtDataSetBase','DataSet provided to prtAction %s''s run() was a prtDataSetBase, DataSet is a %s',class(Obj),class(DataSetIn));
            end
                
            DataSetOut = preRunProcessing(Obj, DataSetIn);
            DataSetOut = runAction(Obj, DataSetOut);
            DataSetOut = postRunProcessing(Obj, DataSetIn, DataSetOut);
        end
        
        function Obj = set.verboseStorage(Obj,val)
            assert(numel(val)==1 && (islogical(val) || (isnumeric(val) && (val==0 || val==1))),'prtAction:invalidVerboseStorage','verboseStorage must be a logical');
            Obj.verboseStorage = logical(val);
        end
        
        function [OutputDataSet, TrainedActions] = crossValidate(Obj, DataSet, validationKeys)
            % CROSSVALIDATE  Cross validate prtAction using prtDataSet and cross validation keys.
            %
            %  OUTPUTDATASET = OBJ.crossValidate(DATASET, KEYS) cross
            %  validates the prtAction object OBJ using the prtDataSet
            %  DATASET and the KEYS. DATASET must be a labeled prtDataSet.
            %  KEYS must be a vector of integers with the same number of
            %  elements as DataSet has observations.
            %
            %  The KEYS are are used to parition the input DataSet into
            %  test and training data sets. For each unique key, a test set
            %  will be created out of the corresponding observations of the
            %  prtDataSet. The remaining observations will be used as
            %  training data.
            %
            %  [OUTPUTDATASET, TRAINEDACTIONS] = OBJ.crossValidate(DATASET,
            %  KEYS) outputs the trained prtAction objects TRAINEDACTIONS.
            %  TRAINEDACTIONS will have a length equal to the number of
            %  unique KEYS.
            
            
            if ~Obj.isCrossValidateValid
                %Should this error?
                warning('prtAction:crossValidate','The input object of type %s has isCrossValidateValid set to false; the outputs of cross-validation may be meaningless',class(Obj));
            end
            if ~isvector(validationKeys) || (numel(validationKeys) ~= DataSet.nObservations)
                error('prt:prtAction:crossValidate','validationKeys must be a vector with a length equal to the number of observations in the data set');
            end
            
            uKeys = unique(validationKeys);
            
            for uInd = 1:length(uKeys);
                    
                %get the testing indices:
                if isa(uKeys(uInd),'cell')
                    cTestLogical = strcmp(uKeys(uInd),validationKeys);
                else
                    cTestLogical = uKeys(uInd) == validationKeys;
                end
                
                testDataSet = DataSet.retainObservations(cTestLogical);
                if length(uKeys) == 1  %1-fold, incestuous train and test
                    trainDataSet = testDataSet;
                else
                    trainDataSet = DataSet.removeObservations(cTestLogical);
                end
                %fprintf('Original: %d, Train: %d, Test: %d\n',DataSet.nObservations,trainDataSet.nObservations,testDataSet.nObservations);
                
                classOut = Obj.train(trainDataSet);
                currResults = classOut.run(testDataSet);
                
                if currResults.nObservations < 1
                    error('prt:prtAction:crossValidate','A cross-validation fold returned a data set with no observations.')
                end
                if uInd == 1
                    nOutputDimensions = length(currResults.getX(1,:));
                end
                if nOutputDimensions ~= length(currResults.getX(1,:));
                    error('prt:prtAction:crossValidate','A cross-validation fold returned a data set with a different number of dimensions than a previous fold.')
                end
                
                if uInd == 1
                    InternalOutputDataSet = currResults;
                    
                    OutputMat = nan(DataSet.nObservations, nOutputDimensions);
                end
                OutputMat(cTestLogical,:) = currResults.getObservations();
                
                %only do this if the output is requested; otherwise this cell of
                %classifiers can get very large, and slow things down.
                if nargout >= 2
                    if uInd == 1
                        % First iteration pre-allocate
                        TrainedActions = repmat(classOut,length(uKeys),1);
                    else
                        TrainedActions(uInd) = classOut;
                    end
                end
            end	
            
            OutputDataSet = DataSet;
            OutputDataSet = OutputDataSet.setObservations(OutputMat);
            OutputDataSet = OutputDataSet.setFeatureNames(InternalOutputDataSet.getFeatureNames);
        end
        
        function varargout = kfolds(Obj,DataSet,K)
            % KFOLDS  Perform K-folds cross validation of prtAction
            % 
            %    OUTPUTDATASET = Obj.KFOLDS(DATASET, K) performs K-folds
            %    cross validation of the prtAction object OBJ using the
            %    prtDataSet DATASET. DATASET must be a labeled prtDataSet,
            %    and K must be a scalar interger, representing the number
            %    of folds. KFOLDS Generates cross validation keys by
            %    patitioning the dataSet into K groups such that the number
            %    of samples of each uniqut target type is attempted to be
            %    held constant.
            %
            %    [OUTPUTDATASET, TRAINEDACTIONS, CROSSVALKEYS] =
            %    Obj.KFOLDS(DATASET, K)  outputs the trained prtAction
            %    objects TRAINEDACTIONS, and the generated cross-validation
            %    keys CROSSVALKEYS.
            
            assert(isa(DataSet,'prtDataSetBase'),'First input must by a prtDataSet.');
            
            if nargin == 2 || isempty(K)
                K = DataSet.nObservations;
            end
            
            nObs = DataSet.nObservations;
            if K > nObs;
                warning('prt:prtAction:kfolds:nFolds','Number of folds (%d) is greater than number of data points (%d); assuming Leave One Out training and testing',K,nObs);
                K = nObs;
            elseif K < 1
                warning('prt:prtAction:kfolds:nFolds','Number of folds (%d) is less than 1 assuming FULL training and testing',K);
                K = 1;
            end
            
            if DataSet.isLabeled
                keys = prtUtilEquallySubDivideData(DataSet.getTargets(),K);
            else
                %can cross-val on unlabeled data, too!
                keys = prtUtilEquallySubDivideData(ones(DataSet.nObservations,1),K);
            end
            
            outputs = cell(1,min(max(nargout,1),2));
            [outputs{:}] = Obj.crossValidate(DataSet,keys);
            
            varargout = outputs(:);
            if nargout > 2
                varargout = [varargout; {keys}];
            end
        end
    end
    
    methods (Access=protected, Hidden= true)
        function ClassObj = preTrainProcessing(ClassObj,DataSet) %#ok<INUSD>
            % preTrainProcessing - Processing done prior to trainAction()
            %   Called by train(). Can be overloaded by prtActions to
            %   store specific information about the DataSet or Classifier
            %   prior to training.
            %   
            %   ClassObj = preTrainProcessing(ClassObj,DataSet)
        end
        
        function ClassObj = postTrainProcessing(ClassObj,DataSet) %#ok<INUSD>
            % postTrainProcessing - Processing done after trainAction()
            %   Called by train(). Can be overloaded by prtActions to
            %   store specific information about the DataSet or Classifier
            %   prior to training.
            %   
            %   ClassObj = postTrainProcessing(ClassObj,DataSet)
        end
        
        function DataSet = preRunProcessing(ClassObj, DataSet) %#ok<MANU>
            % preRunProcessing - Processing done before runAction()
            %   Called by run(). Can be overloaded by prtActions to
            %   store specific information about the DataSet or Classifier
            %   prior to runAction.
            %   
            %   DataSet = preRunProcessing(ClassObj, DataSet)
        end        
        
        function DataSetOut = postRunProcessing(ClassObj, DataSetIn, DataSetOut)
            % postRunProcessing - Processing done after runAction()
            %   Called by run(). Can be overloaded by prtActions to alter
            %   the results of run() to modify outputs using parameters of
            %   the prtAction.
            %   
            %   DataSet = postRunProcessing(ClassObj, DataSet)
            
            if DataSetIn.nObservations > 0
                if ClassObj.isCrossValidateValid
                    if DataSetIn.isLabeled && ~DataSetOut.isLabeled
                        DataSetOut = DataSetOut.setTargets(DataSetIn.getTargets);
                    end
                    DataSetOut = DataSetOut.copyDescriptionFieldsFrom(DataSetIn);
                end
                DataSetOut = ClassObj.updateDataSetFeatureNames(DataSetOut);
            end
        end
        
    end
    methods (Access = protected, Hidden)
        function DataSetOut = runActionOnTrainingData(Obj, DataSetIn)
            % RUNACTIONONTRAININGDATA Run a prtAction object on a prtDataSet object
            %   This method differs from RUN() in that it is called after
            %   train() within prtAlgorithm prior to training of subsequent
            %   actions. By default this method is the same as RUN() but it
            %   can be overloaded by prtActions to enable things such as 
            %   outlier removal.
            %
            %    DataSetOut = runOnTrainingData(Obj DataSetIn);
            
            DataSetOut = runAction(Obj, DataSetIn);
        end
    end
    methods (Hidden)
        function [optimizedAction,performance] = optimize(Obj,DataSet,objFn,parameterName,parameterValues)
            % OPTIMIZE Optimize action parameter by exhaustive function 
            % maximization.
            %
            % Although functional it is currently hidden.
            % At this point it is not possible to optimize parameters of
            % parameters. 
            %
            % Example:
            %   objFn = @(act,ds) = prtEvalAuc(act,ds,3);
            %   [optimizedAction,performance] = optimize(Obj,DataSet,objFn,parameterName,parameterValues)
            %  
            
            if isnumeric(parameterValues);
                parameterValues = num2cell(parameterValues);
            end
            performance = nan(length(parameterValues),1);
            for i = 1:length(performance)
                Obj.(parameterName) = parameterValues{i};
                performance(i) = objFn(Obj,DataSet);
            end
            [maxPerformance,maxPerformanceInd] = max(performance); %#ok<ASGLU>
            Obj.(parameterName) = parameterValues{maxPerformanceInd};
            optimizedAction = train(Obj,DataSet);
            
        end
    end
end