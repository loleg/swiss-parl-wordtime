
import JSON
import HTTP
import HTTP.URIs: escapeuri

using CSV
using Dates
using DelimitedFiles
using DataFrames       # http://juliadata.github.io/DataFrames.jl/stable/index.html
using Feather          # https://juliadata.github.io/Feather.jl/latest/index.html

# Which date range are we interested in
const FILTER_FROM = DateTime(2015,11,30)
const FILTER_TO = DateTime(2018,12,14)

# Names of cache files
const CACHE_PARL = "XODataExport.csv"
const CACHE_TRAN = "ws-parlament-data.feather"

# Configure the transcript web service
p_top = 1000                # How many results per page? (e.g. 1000)
p_max = 0                  # Max number of pages? (e.g. 268)
p_pause = 1                 # Pause between pages (e.g. 2 seconds)?
p_lang = "DE"               # Language of transcripts
p_years = range(2015, stop=2018) # Which set of years to include
p_startfrom = nothing       # To resume download, change this identifier to the first ID

# Open Data Web services of the Swiss parliament
# See: https://www.parlament.ch/de/services/open-data-webservices
const baseurl = "https://ws.parlament.ch/odata.svc/Transcript?\$format=json"
const counturl = "https://ws.parlament.ch/odata.svc/Transcript/$count?"

# Result counts:
#2015	10684
#2016	10407
#2017	9348
#2018	9596
#SUM:	40035

# Create empty input object
df3 = nothing
drefs = []

# Set up year counters
a_years = Array(p_years)
p_year = pop!(a_years)

# Check for previous runs
if isfile(CACHE_TRAN)
    println("Loading transcripts from disk ...")
    df3 = DataFrame(Feather.read(CACHE_TRAN))
    drefs = convert(Array, df3.ID)
end

# Iterate through pages, building an array
println("Starting with year $p_year")
pp = 0
while (pp < p_max)
    # Build the query URL
    pp = pp + 1
    pp0 = (pp - 1) * p_top
    # Build the query
    #https://ws.parlament.ch/odata.svc/Transcript?$top=10&$filter=startswith(MeetingDate, '2015') eq true and PersonNumber ne null and Language eq 'DE'&$orderby=ID&$select=CantonAbbreviation,CantonId,CantonName,CouncilId,CouncilName,End,Function,ID,Language,LanguageOfText,PersonNumber,SpeakerFullName,Start,Text
    #&$orderby=ID ...  and ID ge $(p_startfrom)L
    q_filter = escapeuri("startswith(MeetingDate, '$(p_year)') eq true and Language eq '$(p_lang)' and PersonNumber ne null")
    q_columns = escapeuri("CantonAbbreviation,CantonId,CantonName,CouncilId,CouncilName,End,Function,ID,IdSession,Language,PersonNumber,SpeakerFullName,Start,Text")
    q2 = string("&\$filter=$(q_filter)&\$top=$(p_top)&\$skip=$(pp0)&\$select=$(q_columns)")
    r2 = nothing
    try
        r2 = HTTP.get("$baseurl$q2")
        if r2.status != 200
            throw(Exception("Not status 200"))
        end
    catch e
        println("$baseurl$q2")
        println("HTTP error on page $pp")
        println(r2.status)
        println(r2.body)
        sleep(p_pause)
        break
    end

    d2_data = nothing
    d2_size = 0
    d2 = JSON.parse(String(r2.body))
    d2_data = d2["d"]
    d2_size = size(d2_data, 1)
    if d2_size == 0
        if length(a_years) > 0
            p_year = pop!(a_years)
            pp = 0
            println("Continuing to year $p_year")
            continue
        end
        println("No data received on page $pp, stopping.")
        break
    end
    println("Collected page $pp/$p_max ($d2_size entries)")

    # Append the dataset by index (only once per language)
    df2set = nothing
    for n in range(1, stop=size(d2_data, 1))
        tid = d2_data[n]["ID"]
        if tid in drefs
            continue
        end
        push!(drefs, tid)
        if d2_data[n]["CouncilName"] == nothing
            d2_data[n]["CouncilName"] = "?"
            d2_data[n]["CouncilId"] = 0
        end
        if d2_data[n]["CantonName"] == nothing
            d2_data[n]["CantonName"] = "?"
            d2_data[n]["CantonAbbreviation"] = "?"
            d2_data[n]["CantonId"] = 0
        end

        # Create temporary frame
        d2_frame = DataFrame(d2_data[n])

        # Cleanup bulky or unneeded columns
        deletecols!(d2_frame, [:__metadata])

        # Append to temporary data frame
        if df2set == nothing
            df2set = d2_frame
        else
            df2set = vcat(df2set, d2_frame)
        end
    end

    # Append to our global data frame
    if df2set == nothing
        continue
    elseif df3 == nothing
        df3 = df2set
    else
        df3 = vcat(df3, df2set)
    end

    dsize = size(df3, 1)
    lastid = last(df3).ID
    println("Appended to frame buffer ($dsize @ $lastid)")

    # Sit a while, and listen ...
    sleep(p_pause)
    
    # Check for empty data
    for r in names(df3)
        if typeof(df3[r]) == Array{Union{Nothing, String}, 1} || typeof(df3[r]) == Array{Union{Nothing, Int64}, 1}
            println(r, " ", typeof(df3[r]))
        end
    end
    
    # Write to file
    Feather.write(CACHE_TRAN, df3)
    println("Saved to disk")
end

# Show the number of records saved/loaded, across how many columns
println(size(df3))

# Show an excerpt of transcript data
show(first(df3, 3), allcols=true)

# Helper function to clean the transcript buffer
function cleantext(text)
    text = replace(text, r"<[^>]*>" => "")
    text = replace(text, r"\n" => "")
    return text
end

# Sample content
cleantext("<pd_text><p>Les textes des projets de loi soumis au vote final ont été envoyés hier en fin de journée à tous les membres du conseil par courriel. La version imprimée sur papier n'est plus distribuée, conformément aux décisions des Bureaux des deux conseils de l'année dernière. Toutefois, des exemplaires sur papier sont à disposition dans la salle pour celles et ceux qui souhaitent s'en servir.</p>\n<p>La Commission de rédaction a examiné tous les textes et a certifié leur conformité dans les différentes versions linguistiques.</p>\n</pd_text>")

# Load list of parlamentarians
# Query: https://ws.parlament.ch/odata.svc/Person?$top=10000&$filter=Language eq 'DE'&$select=MembersCouncil/CouncilName,GenderAsString,NativeLanguage,OfficialName,PersonIdCode,ID,PlaceOfBirthCanton,MembersCouncil/CouncilAbbreviation,MembersCouncil/ParlGroupAbbreviation,MembersCouncil/ParlGroupFunction,MembersCouncil/ParlGroupNumber,MembersCouncil/ParlGroupName,MembersCouncil/PartyAbbreviation,MembersCouncil/PartyName,MembersCouncil/DateJoining,MembersCouncil/DateLeaving,MembersCouncil/GenderAsString&$expand=MembersCouncil
parl = CSV.read(CACHE_PARL)
first(parl, 3)

function wordcount(text)
    text = cleantext(text)
    words = split(text, Regex(join([" ","\n","\t","-","\\.",",",":","_","\"",";","!"], "|")))
    #print(words)
    return length(words)
end

function getdate(text)
    return unix2datetime(parse(Int64, replace(text, r"/|\(|\)|Date" => ""))/1000)
end

function getparlfld(id, fld)
    l = nothing
    if isa(id, SubArray)
        id = id[1] 
    end
    try
        l = parl[parl.ID .== id, fld]
    catch e
        println("Could not match $fld on $id")
        return "?"
    end
    if size(l, 1) > 0
        return l[1][1] 
    end
    "?"
end

df3t = by(df3, [:ID, :IdSession, :CouncilName, :PersonNumber, :SpeakerFullName]) do r
    (
        OfficialName = getparlfld(r.PersonNumber, [:OfficialName]),
        Start = getdate(r.Start[1]),
        Duration = ceil(getdate(r.End[1]) - getdate(r.Start[1]), Dates.Second),
        WordCount = wordcount(r.Text[1]),
        Gender = getparlfld(r.PersonNumber, [:GenderAsString]),
        Rat = getparlfld(r.PersonNumber, [:CouncilName]),
        Partei = getparlfld(r.PersonNumber, [:PartyName]),
        Fraktion = getparlfld(r.PersonNumber, [:ParlGroupName]),
        IsPM = r.Function[1] in ["P-M", "AP-M", "BPR-F"] ? 1 : 0,
        One = 1
    )
end
first(df3t,3)

# Apply date filters
dflt = df3t[df3t.Start .>= FILTER_FROM, :]
dflt = dflt[dflt.Start .<= FILTER_TO, :]
dflt = dflt[dflt.Duration .<= Dates.Hour(6), :]
first(dflt,3)

# Aggregate times
#by(iris, :Species, [:PetalLength, :SepalLength] =>
#              x -> (a=mean(x.PetalLength)/mean(x.SepalLength), b=sum(x.PetalLength)))
#aggregate(dflt, :PersonNumber, [:Duration])

dout = by(dflt, [:PersonNumber, :SpeakerFullName, :Gender, :Rat, :Partei, :Fraktion], 
    [:IsPM, :Duration, :WordCount, :IdSession, :One] => x -> 
    (
        PMCount=sum(x.IsPM), 
        TotalDuration=Dates.value(sum(x.Duration)), 
        TotalWords=sum(x.WordCount), 
        TotalSessions=length(unique(x.IdSession)),
        TotalTranscripts=sum(x.One)
    )
)
first(dout,3)

# Create a filtered copy of the data frame
dfltr = dout[:, :]
# Subtract those who were in the Bundesrat
#dfltr = dfltr[dfltr.Rat .!== "Bundesrat", :]
# Subtract those who have been P-M at least once
#dfltr = dfltr[dfltr.PMCount .== 0, :]
size(dfltr)

# Output file to disk
CSV.write("output.csv", dfltr, delim = ';')

# TODO: update Data Package

# 3880 74

CSV.write("test2.csv", df3t[df3t.PersonNumber .== 3880, :], delim = ';')

show(df3[df3.ID .== "215124", :], allcols=true)

show(df3[df3.ID .== "206655", :], allcols=true)

println(size(dflt[dflt.Duration .<= Dates.Hour(6), :]))
println(size(dflt))
