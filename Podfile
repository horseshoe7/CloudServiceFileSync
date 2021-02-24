
platform :ios, '13.0'

abstract_target 'CloudSync' do
    
    inhibit_all_warnings!
    use_frameworks!

    target 'CloudServiceFileSync' do
    
        pod 'SwiftyDropbox'
        
        target 'CloudServiceFileSyncTests' do
            inherit! :search_paths
        end
    end
    
    target 'CloudSyncSandbox' do
        pod 'SwiftyDropbox'
    end
    
end
