#include <iostream>
#include "fhiclcpp/ParameterSet.h"
#include "fhiclcpp/make_ParameterSet.h"

#include <boost/program_options.hpp>

using namespace fhicl;
namespace bpo = boost::program_options;

int main(int argc, char* argv[]) try
{
	// Get the input parameters via the boost::program_options library,
	// designed to make it relatively simple to define arguments and
	// issue errors if argument list is supplied incorrectly

	std::ostringstream descstr;
	descstr << *argv << " <-c <config-file>> <other-options>";

	bpo::options_description desc = descstr.str();

	desc.add_options()("config,c", bpo::value<std::string>(), "Configuration file.")("help,h",
	                                                                                 "produce help message");

	bpo::variables_map vm;

	try
	{
		bpo::store(bpo::command_line_parser(argc, argv).options(desc).run(), vm);
		bpo::notify(vm);
	}
	catch (bpo::error const& e)
	{
		std::cerr << "Exception from command line processing in " << *argv << ": " << e.what() << "\n";
		return -1;
	}

	if (vm.count("help") != 0u)
	{
		std::cout << desc << std::endl;
		return 1;
	}
	if (vm.count("config") == 0u)
	{
		std::cerr << "Exception from command line processing in " << *argv << ": no configuration file given.\n"
		          << "For usage and an options list, please do '" << *argv << " --help"
		          << "'.\n";
		return 2;
	}

	// Check the directories defined by the FHICL_FILE_PATH
	// environmental variable for the *.fcl file whose name was passed to
	// the command line. If not defined, look in the current directory.

	ParameterSet complete_pset;

	if (getenv("FHICL_FILE_PATH") == nullptr)
	{
		std::cerr << "INFO: environment variable FHICL_FILE_PATH was not set. Using \".\"\n";
		setenv("FHICL_FILE_PATH", ".", 0);
	}

	auto file_name = vm["config"].as<std::string>();
	auto filepath_maker = cet::filepath_lookup("FHICL_FILE_PATH");

	make_ParameterSet(file_name, filepath_maker, complete_pset);

	std::cout << complete_pset.to_indented_string(0, false) << "\n";

	return 0;
}

catch (std::exception const& x)
{
	std::cerr << "Exception (type std::exception) caught in driver: " << x.what() << "\n";
	return 1;
}
catch (...)
{
	return -1;
}
