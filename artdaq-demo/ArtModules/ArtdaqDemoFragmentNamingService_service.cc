#include "artdaq-core-demo/Overlays/FragmentType.hh"
#include "artdaq/ArtModules/ArtdaqFragmentNamingService.h"

#include "TRACE/tracemf.h"
#define TRACE_NAME "ArtdaqDemoFragmentNamingService"

/**
 * \brief ArtdaqDemoFragmentNamingService extends ArtdaqFragmentNamingService.
 * This implementation uses artdaq-demo's SystemTypeMap and directly assigns names based on it
 */
class ArtdaqDemoFragmentNamingService : public ArtdaqFragmentNamingService
{
public:
	/**
	 * \brief DefaultArtdaqFragmentNamingService Destructor
	 */
	~ArtdaqDemoFragmentNamingService() override = default;

	/**
	 * \brief ArtdaqDemoFragmentNamingService Constructor
	 */
	ArtdaqDemoFragmentNamingService(fhicl::ParameterSet const& /*ps*/, art::ActivityRegistry& /*r*/);

private:
};

ArtdaqDemoFragmentNamingService::ArtdaqDemoFragmentNamingService(fhicl::ParameterSet const& ps, art::ActivityRegistry& r)
    : ArtdaqFragmentNamingService(ps, r)
{
	TLOG(TLVL_DEBUG) << "ArtdaqDemoFragmentNamingService CONSTRUCTOR START";
	SetBasicTypes(demo::makeFragmentTypeMap());
	TLOG(TLVL_DEBUG) << "ArtdaqDemoFragmentNamingService CONSTRUCTOR END";
}

DECLARE_ART_SERVICE_INTERFACE_IMPL(ArtdaqDemoFragmentNamingService, ArtdaqFragmentNamingServiceInterface, LEGACY)
DEFINE_ART_SERVICE_INTERFACE_IMPL(ArtdaqDemoFragmentNamingService, ArtdaqFragmentNamingServiceInterface)